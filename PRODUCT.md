# Product

## Platform

macos

## Stack

Native macOS app in SwiftUI, compiled with `swiftc` through a Makefile (`make install` builds, installs to /Applications and launches). Minimum macOS 14.

## Users

General Mac users who want a beautiful desktop without thinking about it. Distribution to other people is the intent, not a personal-only tool.

## Product Purpose

Pane keeps the Mac desktop always fresh: it picks high-quality photographs and puts them on the desktop, on demand or automatically on a schedule. Success is a desktop that keeps changing to something worth looking at, with as little effort from the user as possible.

## Positioning

"Mesa sempre nova": the core promise is automatic rotation. The app is meant to fade into the background (menu bar, timer) while the desktop changes by itself; browsing is the secondary path for choosing favorites and sources.

## Operating Context

- Opened occasionally to browse categories, favorite images and adjust rotation; most of the time it lives only in the menu bar.
- Images come from Wikimedia Commons featured pictures (freely licensed), filtered to landscape images at least 1600 px wide. Picsum was tried first and is unreachable on the user's network.
- Applying writes a JPEG to Application Support and calls NSWorkspace to set it on one or all screens.

## Capabilities and Constraints

- Categories: Destaques, Paisagens, Montanhas, Cidades, Pôr do sol, Lagos, Florestas, Cachoeiras, Céus, Flores, Arquitetura.
- Search by title or author, detail view, apply to desktop, download (current screen, 4K, original) to ~/Pictures/Pane.
- Favorites and recent history persisted locally.
- Filters: grayscale and blur, applied both on screen and to the output file.
- Random apply (⇧⌘R) and automatic rotation every 15 minutes to 1 day, drawing from favorites, the current category, or all categories.
- Menu bar extra with quick actions.
- Interface language: Brazilian Portuguese.
- Must work in both macOS light and dark appearance.

## Brand Commitments

- Name: Pane. Original product; nothing may be copied from Wallcraft (name, visuals, text).
- The user explicitly allowed a bold redesign: navigation, layout and structure may change freely.

## Evidence on Hand

- Image content is real Wikimedia Commons photography with author and license per image; attribution must stay visible.
- No logo, icon, testimonials, ratings or store presence exist yet; none may be invented.

## Product Principles

1. The desktop is the product; the window is a way to steer it.
2. Effortless first: one action should be enough to get a new desktop.
3. Photographs lead; interface recedes around them.
4. Credit the photographer every time an image is shown in detail.
