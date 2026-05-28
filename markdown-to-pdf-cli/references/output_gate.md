# Output Gate

- 输出 PDF 必须存在且非空。
- `file` 输出应识别为 PDF。
- 如果 `pdfinfo` 可用，`Pages` 必须大于等于 1。
- 源 Markdown 的相对图片路径必须从 Markdown 所在目录解析。
- Mermaid 渲染失败时不要交付空白 PDF；应报告具体渲染阶段。
