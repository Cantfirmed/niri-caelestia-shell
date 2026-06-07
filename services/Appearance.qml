pragma Singleton

import QtQuick
import Caelestia.Config

QtObject {
    readonly property var anim: Tokens.anim
    readonly property var font: QtObject {
        readonly property string sans: Tokens.font.body.medium.family
        readonly property string mono: Tokens.font.mono.medium.family
        readonly property var family: QtObject {
            readonly property string sans: Tokens.font.body.medium.family
            readonly property string mono: Tokens.font.mono.medium.family
        }
        readonly property var size: QtObject {
            readonly property real bodySmall: Tokens.font.body.small.pointSize
            readonly property real bodyMedium: Tokens.font.body.medium.pointSize
            readonly property real bodyLarge: Tokens.font.body.large.pointSize
            readonly property real labelSmall: Tokens.font.label.small.pointSize
            readonly property real labelMedium: Tokens.font.label.medium.pointSize
            readonly property real labelLarge: Tokens.font.label.large.pointSize
            readonly property real titleSmall: Tokens.font.title.small.pointSize
            readonly property real titleMedium: Tokens.font.title.medium.pointSize
            readonly property real titleLarge: Tokens.font.title.large.pointSize
            readonly property real headlineSmall: Tokens.font.headline.small.pointSize
            readonly property real headlineMedium: Tokens.font.headline.medium.pointSize
            readonly property real headlineLarge: Tokens.font.headline.large.pointSize
            readonly property real large: Tokens.font.body.large.pointSize
        }
    }
    readonly property var padding: QtObject {
        readonly property int xs: Tokens.padding.extraSmall
        readonly property int sm: Tokens.padding.small
        readonly property int md: Tokens.padding.medium
        readonly property int lg: Tokens.padding.large
        readonly property int xl: Tokens.padding.extraLarge
        readonly property int extraSmall: Tokens.padding.extraSmall
        readonly property int small: Tokens.padding.small
        readonly property int medium: Tokens.padding.medium
        readonly property int large: Tokens.padding.large
        readonly property int extraLarge: Tokens.padding.extraLarge
    }
    readonly property var rounding: QtObject {
        readonly property int xs: Tokens.rounding.extraSmall
        readonly property int sm: Tokens.rounding.small
        readonly property int md: Tokens.rounding.medium
        readonly property int lg: Tokens.rounding.large
        readonly property int xl: Tokens.rounding.extraLarge
        readonly property int full: Tokens.rounding.full
        readonly property int extraSmall: Tokens.rounding.extraSmall
        readonly property int small: Tokens.rounding.small
        readonly property int medium: Tokens.rounding.medium
        readonly property int normal: Tokens.rounding.medium
        readonly property int large: Tokens.rounding.large
        readonly property int extraLarge: Tokens.rounding.extraLarge
    }
    readonly property var spacing: QtObject {
        readonly property int xs: Tokens.spacing.extraSmall
        readonly property int sm: Tokens.spacing.small
        readonly property int md: Tokens.spacing.medium
        readonly property int lg: Tokens.spacing.large
        readonly property int xl: Tokens.spacing.extraLarge
        readonly property int extraSmall: Tokens.spacing.extraSmall
        readonly property int small: Tokens.spacing.small
        readonly property int medium: Tokens.spacing.medium
        readonly property int large: Tokens.spacing.large
        readonly property int extraLarge: Tokens.spacing.extraLarge
    }
    readonly property var sizes: Tokens.sizes
}
