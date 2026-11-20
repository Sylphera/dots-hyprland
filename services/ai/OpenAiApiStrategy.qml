import QtQuick

ApiStrategy {
    property bool isReasoning: false
    property bool browserSearch: false

    function explicitlyRequestsSearch(text: string): bool {
        const query = text.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
        if (/\b(?:no|sin|without|never|don['’]t|do not)\s+(?:busc\w*|naveg\w*|search\w*|brows\w*|look up)\b/.test(query))
            return false;
        return /\b(?:busca(?:me|lo|la|los|las)?|investiga(?:me|lo|la)?|(?:puedes|podrias)\s+buscar|(?:search|browse)\s+(?:the\s+)?(?:web|internet|online)|look\s+up|google\s+it)\b/.test(query);
    }
    
    function buildEndpoint(model: AiModel): string {
        // console.log("[AI] Endpoint: " + model.endpoint);
        return model.endpoint;
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        if (browserSearch) {
            systemPrompt += `\n\nYou are ${model.name} (${model.model}), hosted by Groq. The focused desktop app is separate from your identity. You have a web search tool. Use it for requested or time-sensitive research, cite the sources with links, and say you searched only if you actually used the tool. Reply in the language of the latest user message, even if these instructions, earlier replies, or the sources are in another language.`;
        }
        let baseData = {
            "model": model.model,
            "messages": [
                {role: "system", content: systemPrompt},
                ...messages.map(message => {
                    return {
                        "role": message.role,
                        "content": message.rawContent,
                    }
                }),
            ],
            "stream": true,
            "tools": tools,
            "temperature": temperature,
        };
        if (browserSearch) {
            const lastUserMessage = [...messages].reverse().find(message => message.role === "user");
            baseData.tools = [{type: "browser_search"}];
            baseData.tool_choice = explicitlyRequestsSearch(lastUserMessage?.rawContent ?? "") ? "required" : "auto";
        }
        return model.extraParams ? Object.assign({}, baseData, model.extraParams) : baseData;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "Authorization: Bearer \$\{${apiKeyEnvVarName}\}"`;
    }

    function parseResponseLine(line, message) {
        // Remove 'data: ' prefix if present and trim whitespace
        let cleanData = line.trim();
        if (cleanData.startsWith("data:")) {
            cleanData = cleanData.slice(5).trim();
        }

        // console.log("[AI] OpenAI: Data:", cleanData);
        
        // Handle special cases
        if (!cleanData || cleanData.startsWith(":")) return {};
        if (cleanData === "[DONE]") {
            return { finished: true };
        }
        
        // Real stuff
        try {
            const dataJson = JSON.parse(cleanData);

            // Error response handling
            if (dataJson.error) {
                const errorMsg = `**Error**: ${dataJson.error.message || JSON.stringify(dataJson.error)}`;
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return { finished: true };
            }

            let newContent = "";

            const choice = dataJson.choices?.[0];
            const responseContent = choice?.delta?.content ?? choice?.message?.content ?? dataJson.message?.content;
            const responseReasoning = choice?.delta?.reasoning || choice?.delta?.reasoning_content;

            if (responseContent && responseContent.length > 0) {
                if (isReasoning) {
                    isReasoning = false;
                    const endBlock = "\n\n</think>\n\n";
                    message.content += endBlock;
                    message.rawContent += endBlock;
                }
                newContent = responseContent;
            } else if (responseReasoning && responseReasoning.length > 0) {
                if (!isReasoning) {
                    isReasoning = true;
                    const startBlock = "\n\n<think>\n\n";
                    message.rawContent += startBlock;
                    message.content += startBlock;
                }
                newContent = responseReasoning;
            }

            message.content += newContent;
            message.rawContent += newContent;

            // Usage metadata
            if (dataJson.usage) {
                return {
                    tokenUsage: {
                        input: dataJson.usage.prompt_tokens ?? -1,
                        output: dataJson.usage.completion_tokens ?? -1,
                        total: dataJson.usage.total_tokens ?? -1
                    }
                };
            }

            if (dataJson.done) {
                return { finished: true };
            }
            
        } catch (e) {
            console.log("[AI] OpenAI: Could not parse line: ", e);
            message.rawContent += line;
            message.content += line;
        }
        
        return {};
    }
    
    function onRequestFinished(message) {
        // OpenAI format doesn't need special finish handling
        return {};
    }
    
    function reset() {
        isReasoning = false;
    }

}
