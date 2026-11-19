import QtQuick
import qs.services

QtObject {
    property string name
    property list<string> categories
    // Also takes the apps none of `otherCategories` has: Windows gives apps no
    // categories, which left every folder empty.
    property bool catchesRest: false
    property list<string> otherCategories
}
