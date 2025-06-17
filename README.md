# Sales Document Dimension Processor

Copy default customer and item dimensions onto Business Central sales headers and lines automatically

## Overview

This extension automatically populates dimensions in sales documents when:

1. Documents are created without dimensions
2. Dimension values are missing but required by business rules

## Key Features

- **Automatic Dimension Population**:
  - Copies customer dimensions to sales headers
  - Copies item dimensions to sales lines
- **Value Enforcement**:
  - Fills empty dimension values when required by Value Posting rules
- **Comprehensive Processing**:
  - Handles all sales document types (orders, invoices, quotes, etc.)
  - Processes both headers and lines
- **Safe Operations**:
  - Only processes documents with `Dimension Set ID = 0`
  - Preserves existing valid dimensions
