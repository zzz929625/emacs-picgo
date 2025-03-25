# picgo.el - PicGo integration for Emacs

这个Emacs插件提供了与[PicGo](https://github.com/PicGo/PicGo-Core)的集成，使你能够方便地在Emacs中上传图片到图床，并自动替换或插入图片链接。

## 功能特点

- 支持上传当前光标处的图片链接到图床并自动替换
- 支持批量上传文档中所有图片链接
- 支持从剪贴板中直接上传图片并插入链接
- 同时支持Org Mode和Markdown格式
- 支持本地图片文件和远程图片URL的上传

## 依赖

- [PicGo-Core](https://github.com/PicGo/PicGo-Core) (CLI版本)

## 安装

### 1. 安装PicGo-Core

首先需要安装PicGo-Core CLI工具：

```bash
npm install -g picgo
```

然后配置PicGo，创建配置文件：

```bash
picgo set uploader
```

按照提示选择你喜欢的图床并进行配置。

### 2. 安装picgo.el

#### 手动安装

1. 将`picgo.el`文件放到你的Emacs配置目录中
2. 在你的配置文件中添加：

```elisp
(add-to-list 'load-path "/path/to/picgo.el")
(require 'picgo)
```

#### 使用Doom Emacs

1. 将`picgo.el`放到`~/.doom.d/lisp/`目录下
2. 在`config.el`中添加：

```elisp
(add-to-list 'load-path "~/.doom.d/lisp/")
(require 'picgo)
```

## 使用方法

### 设置快捷键

你可以根据自己的喜好设置快捷键，例如：

```elisp
;; 设置上传当前光标处的图片链接的快捷键
(global-set-key (kbd "C-c i u") 'picgo-upload-image-at-point)

;; 设置批量上传当前文档中的所有图片的快捷键
(global-set-key (kbd "C-c i b") 'picgo-batch-upload-images)

;; 设置上传剪贴板中的图片到当前位置的快捷键
(global-set-key (kbd "C-c i p") 'picgo-upload-clipboard-image)
```

### 手动调用函数

你也可以直接调用这些函数：

- `M-x picgo-upload-image-at-point`: 上传当前光标处的图片链接
- `M-x picgo-batch-upload-images`: 批量上传所有图片链接
- `M-x picgo-upload-clipboard-image`: 上传剪贴板图片

## 自定义设置

你可以自定义PicGo可执行文件的位置：

```elisp
(setq picgo-executable "/path/to/picgo")
```

## 工作原理

1. **上传当前光标处的图片链接**：
   - 检测光标所在位置是否有图片链接
   - 提取图片URL（本地文件或远程URL）
   - 使用PicGo上传图片
   - 用生成的新URL替换原链接

2. **批量上传**：
   - 扫描整个文档寻找图片链接
   - 对每个链接执行上传操作
   - 自动替换为新链接

3. **剪贴板上传**：
   - 直接调用PicGo上传剪贴板中的图片
   - 将返回的URL插入到当前光标位置，格式化为当前文档类型的链接格式

## 支持的文档类型

- **Org Mode**：支持`[[url]]`和`[[url][description]]`格式
- **Markdown**：支持`![description](url)`格式

## 注意事项

- 确保PicGo CLI工具已正确安装并可在PATH中找到
- 上传前请确保PicGo已正确配置了图床信息

## 许可

本插件采用MIT许可证。 