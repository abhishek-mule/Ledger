# 🎨 Visual Design Reference & Style Guide

**Ledger App - Design System v2.0**  
**Date:** February 10, 2026  
**Status:** ✅ Complete & Ready

---

## COLOR PALETTE

### Primary Colors
```
Primary Blue:
  Color Code: #2563EB
  RGB: (37, 99, 235)
  Usage: Main actions, links, focus states
  Examples: Start button, primary calls-to-action
  
Primary Light:
  Color Code: #60A5FA
  RGB: (96, 165, 250)
  Usage: Hover states, light backgrounds
  
Primary Container:
  Color Code: #1E40AF
  RGB: (30, 64, 175)
  Usage: Pressed states, dark accents
```

### Secondary Colors
```
Secondary Teal:
  Color Code: #0D9488
  RGB: (13, 148, 136)
  Usage: Alternative accent, secondary actions
  
Secondary Light:
  Color Code: #2DD4BF
  RGB: (45, 212, 191)
  Usage: Hover states for secondary actions
```

### Semantic Colors
```
Success Green:
  Color Code: #10B981
  RGB: (16, 185, 129)
  Usage: Completion, positive feedback, success states
  
Warning Amber:
  Color Code: #F59E0B
  RGB: (245, 158, 11)
  Usage: Warnings, cautions, non-critical alerts
  
Error Red:
  Color Code: #EF4444
  RGB: (239, 68, 68)
  Usage: Errors, critical alerts, destructive actions
```

### Background Colors
```
Background Dark (Primary):
  Color Code: #0F1419
  RGB: (15, 20, 25)
  Usage: App background, primary dark surface
  
Surface Dark:
  Color Code: #1A2332
  RGB: (26, 35, 50)
  Usage: Cards, modals, elevated content
  
Surface Variant Dark:
  Color Code: #252E3A
  RGB: (37, 46, 58)
  Usage: Secondary surfaces, dividers
  
Surface Elevated:
  Color Code: #2A3847
  RGB: (42, 56, 71)
  Usage: Highest elevation surfaces, overlays
```

### Text Colors
```
Text Primary:
  Color Code: #F1F5F9
  RGB: (241, 245, 249)
  Usage: Main text content
  Contrast: 16:1 on background
  
Text Secondary:
  Color Code: #CBD5E1
  RGB: (203, 213, 225)
  Usage: Secondary information, labels
  Contrast: 11:1 on background
  
Text Tertiary:
  Color Code: #94A3B8
  RGB: (148, 163, 184)
  Usage: Hints, disabled text, helper text
  Contrast: 5.8:1 on background
```

### Neutral Grays
```
Gray 50:   #FAFBFC  (Light mode background)
Gray 100:  #F5F7FB  (Light mode surface)
Gray 200:  #EAEF5  (Light mode variant)
Gray 300:  #DDE3ED
Gray 400:  #BCC5D8
Gray 500:  #8B96A8  (Neutral primary)
Gray 600:  #6B7684
Gray 700:  #505B6F  (Used for borders)
Gray 800:  #35404F
Gray 900:  #1A2332  (Used for dark surfaces)
```

---

## TYPOGRAPHY

### Font Family
**Primary:** Inter  
**Fallback:** SF Pro Display, Segoe UI, Helvetica

### Type Scale

#### Display
```
Display Large:
  Size: 57px
  Weight: 700
  Line Height: 1.2
  Letter Spacing: -0.25
  Usage: Intro screens, large headings

Display Medium:
  Size: 45px
  Weight: 700
  Usage: Large section headers

Display Small:
  Size: 36px
  Weight: 700
  Usage: Page titles
```

#### Headline
```
Headline Large:
  Size: 32px
  Weight: 700
  Line Height: 1.3
  Usage: Section titles, important headers
  
Headline Medium:
  Size: 28px
  Weight: 700
  Usage: Card titles, screen headers
  
Headline Small:
  Size: 24px
  Weight: 700
  Usage: Subsection headers
```

#### Title
```
Title Large:
  Size: 22px
  Weight: 700
  Usage: Card headers, dialog titles
  
Title Medium:
  Size: 16px
  Weight: 600
  Usage: Task names, item titles
  
Title Small:
  Size: 14px
  Weight: 600
  Usage: Input labels, small titles
```

#### Body
```
Body Large:
  Size: 16px
  Weight: 400
  Line Height: 1.5
  Usage: Main content text, descriptions
  
Body Medium:
  Size: 14px
  Weight: 400
  Usage: General content, helper text
  
Body Small:
  Size: 12px
  Weight: 400
  Usage: Secondary text, hints
```

#### Label
```
Label Large:
  Size: 14px
  Weight: 600
  Usage: Button text, labels
  
Label Medium:
  Size: 12px
  Weight: 600
  Usage: Secondary labels, badges
  
Label Small:
  Size: 11px
  Weight: 600
  Usage: Captions, very small text
```

---

## COMPONENT STYLES

### Buttons

#### Elevated Button (Primary)
```
Background: #2563EB (Primary)
Text: #FFFFFF (white)
Text Size: 14px
Text Weight: 600
Padding: 12px horizontal, 24px vertical
Border Radius: 12px
Elevation: 0px (flat design)
Hover: Lighter blue #60A5FA
Pressed: Darker blue #1E40AF
States:
  - Normal
  - Hover
  - Pressed
  - Disabled (gray with reduced opacity)
```

#### Outlined Button (Secondary)
```
Background: Transparent
Border: 1.5px solid #2563EB
Text: #2563EB
Text Size: 14px
Border Radius: 12px
Padding: 12px horizontal, 24px vertical
Hover: Light blue background #DBEAFEa
```

#### Text Button
```
Background: Transparent
Text: #2563EB
Padding: 8px horizontal, 12px vertical
Border Radius: 8px
No border
Hover: Light background
```

### Cards

#### Standard Card
```
Background: #1A2332 (Surface Dark)
Border: 1px solid #252E3A (Surface Variant)
Border Radius: 14px
Padding: 16px
Shadow: None (flat)
Hover: Slight elevation

Elevated Card:
  Box Shadow: 0 4px 12px rgba(0,0,0,0.2)
  Elevation: 4dp
```

### Input Fields

#### Text Input
```
Background: #252E3A (Surface Variant)
Border: 1px solid #505B6F (Gray 700)
Border Radius: 12px
Padding: 14px horizontal, 14px vertical
Text Color: #F1F5F9 (Text Primary)
Placeholder: #94A3B8 (Text Tertiary)
Focus Border: 2px solid #2563EB (Primary)
Focus: Smooth 200ms transition
```

### Progress Indicator
```
Track Background: #252E3A
Progress Fill: #2563EB (Primary)
Height: 8px
Border Radius: 8px
Animation: Smooth fill
```

### Badge/Chip
```
Background: #2563EB (Primary)
Text: #FFFFFF
Padding: 6px vertical, 12px horizontal
Border Radius: 20px (pill shape)
Text Size: 12px
Weight: 600
```

---

## SPACING SYSTEM

### Base Unit: 4px Grid

```
Spacing Scale:
  4px   - xs
  8px   - sm
  12px  - md
  16px  - lg
  20px  - xl
  24px  - 2xl
  32px  - 3xl
  48px  - 4xl
  64px  - 5xl
```

### Common Spacing Values
```
Component Padding:
  Small: 8px
  Medium: 12px - 16px
  Large: 16px - 20px

Content Margins:
  Horizontal: 16px
  Vertical: 20px - 24px

Gap Between Items:
  Compact: 8px
  Normal: 12px
  Loose: 16px
```

---

## BORDER RADIUS

### Radius Scale
```
Extra Small: 4px    - Minimal, barely rounded
Small:       8px    - Input fields, small components
Medium:      12px   - Cards, buttons
Large:       14px   - Larger cards
XL:          16px   - Elevated surfaces
Pill:        20px+  - Badges, chips
Circle:      50%    - Avatar, icons
```

### Usage
```
Buttons:          12px
Cards:            14px
Input Fields:     12px
Badges:           20px
Icons:            8-12px
Dialogs:          16px
Bottom Sheet:     16px top
```

---

## SHADOWS & ELEVATION

### Shadow System
```
No Shadow (Flat):
  elevation: 0px

Subtle Shadow:
  0 2px 4px rgba(0, 0, 0, 0.1)
  Used for: Slight elevation, cards

Medium Shadow:
  0 4px 12px rgba(0, 0, 0, 0.15)
  Used for: Card elevation, hovered items

Strong Shadow:
  0 8px 24px rgba(0, 0, 0, 0.2)
  Used for: Modals, important components
```

### Glow Effect
```
Status Indicator Glow:
  boxShadow: [
    BoxShadow(
      color: statusColor.withOpacity(0.4),
      blurRadius: 8,
      spreadRadius: 2,
    )
  ]
```

---

## ANIMATIONS

### Transitions
```
Fast:     100ms
Standard: 200ms (default for most transitions)
Slow:     300ms
Slowest:  500ms+

Easing: ease-in-out (Material curves)
```

### Common Animations
```
Container Changes:    200ms
Button Press:         200ms
Expand/Collapse:      250ms
Fade In:              200ms
Slide In:             300ms
Stagger Between:      50-100ms
```

---

## ACCESSIBILITY

### Contrast Ratios
```
AAA Level (7:1+):
  - Primary text on background
  - Button text on button background
  
AA Level (4.5:1+):
  - Secondary text
  - Helper text
  
Minimum (3:1):
  - Large text
  - Icons
  - Decorative elements
```

### Touch Targets
```
Minimum Size:    44px x 44px
Preferred:       48px x 48px
Comfortable:     56px x 56px

Spacing:         8px minimum between touch targets
```

---

## LIGHT MODE (Optional)

When implemented, follow these:
```
Background:      #FAFBFC
Surface:         #FFFFFF
Text Primary:    #0F1419
Text Secondary:  #505B6F
Primary:         #2563EB (same)
Secondary:       #0D9488 (same)
```

---

## USAGE EXAMPLES

### Task Card Component
```
ModernCard(
  backgroundColor: AppColors.surfaceDark,
  borderColor: AppColors.primary.withOpacity(0.5),
  borderWidth: 1.5,
  borderRadius: 14,
  padding: EdgeInsets.all(14),
  child: Row(
    children: [
      // Status indicator with glow
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 2,
            )
          ]
        ),
      ),
      SizedBox(width: 14),
      
      // Content
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Task Name', style: TextStyles.titleMedium),
            SizedBox(height: 6),
            Text('30 min', style: TextStyles.bodySmall),
          ],
        ),
      ),
      
      // Action
      ElevatedButton(
        onPressed: () {},
        child: Text('Start'),
      ),
    ],
  ),
)
```

---

## COLOR COMBINATIONS (Approved Pairs)

```
Blue + White:           Primary action (button)
Blue + Light Blue:      Hover state
Teal + White:          Secondary action
Green + Light Green:    Success states
Red + Light Red:        Error states
Dark Gray + Light Gray: Disabled states
```

---

## FINAL NOTES

This design system is:
- ✅ Consistent across all screens
- ✅ Accessible (WCAG AA+)
- ✅ Modern and professional
- ✅ Easy to maintain
- ✅ Scalable for growth

All components follow Material 3 principles and modern web design best practices.

---

**Design System Version:** 2.0  
**Status:** Production Ready ✅  
**Last Updated:** February 10, 2026

