# Rejected Edits

- 不根据模型名称直接断言支持图片。
- 不默认启用 32768 或更高上下文。
- 不在 selftest 中调用 Ollama API、下载模型或占用 GPU。
- 不建议在 16G 共享内存设备上用单次超长上下文替代分块/RAG。
