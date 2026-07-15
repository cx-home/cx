---
title: CX Language Guide
author: Erik
version: 0.8.0
---

# CX Language Guide

CX is a **structured** markup language with *clean* bracket syntax. It exports to XML, JSON, YAML, and TOML.

## Quick Start

Install and build:

```bash

git clone https://github.com/cx-home/cx
make build              # builds libcx + every binding
make promote-cli        # install the cx CLI

```

Then try `cx --help` to see all options.

## Core Concepts

### Inline Formatting

Supports **bold**, *italic*, ***bold italic***, ~~strikethrough~~, ~subscript~, ^superscript^, <u>underline</u>, and `inline code`.

### Lists

- Clean bracket syntax
- Typed attributes on any element — sized types like ::u16 / ::f64
- Multiple output formats
- Boolean attributes: tls=true / debug=false

### Links

See the [full documentation](https://cxhome.org/docs) for details.

### Tables

| format | input | output |
| --- | --- | --- |
| CX | true | true |
| XML | true | true |
| JSON | true | true |
| YAML | true | true |
| TOML | true | true |

## Images

![CX structure diagram](diagram.png)
