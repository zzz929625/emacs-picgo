# Emacs-Picgo - PicGo integration for Emacs

这个Emacs插件提供了与[PicGo](https://github.com/PicGo/PicGo-Core)和[piclist](https://github.com/Kuingsmile/PicList)的集成，能够方便地在Emacs中上传图片到图床，并自动替换或插入图片链接。

## 功能

- 支持上传当前光标处的图片链接到图床并自动替换
- 支持批量上传文档中所有图片链接
- 支持从剪贴板中直接上传图片并插入链接
- 同时支持Org Mode和Markdown格式
- 支持本地图片文件和远程图片URL的上传

## 依赖与前置要求

需要`picgo`或者`piclist`的core版本，提前设置好图床等配置，能够在**shell**环境下通过**cli**使用`picgo u`命令正常上传图片。

## 2. 安装emacs-picgo

### 手动安装

1. 将`picgo.el`文件放到你的Emacs配置目录中
2. 在你的配置文件中添加：

```elisp
(add-to-list 'load-path "/path/to/picgo.el")
(require 'picgo)
```

### 使用Doom Emacs

在`packages.el`中添加：
```elisp
(package! emacs-picgo
  :recipe (:host github :repo "zzz929625/emacs-picgo"))
```
在`config.el`中声明：

```elisp
(use-package! emacs-picgo
  :config
  ;; 设置PicGo可执行文件的路径（如果需要）
  ;; (setq picgo-executable "/path/to/picgo")
  
  ;; 设置上传图片的快捷键
  (map! :leader
        (:prefix ("i" . "插入")
         :desc "上传当前光标处图片" "u" #'picgo-upload-image-at-point
         :desc "批量上传文档中所有图片" "b" #'picgo-batch-upload-images
         :desc "上传剪贴板图片" "p" #'picgo-upload-clipboard-image))
  
  ;; 或者使用全局快捷键
  ;; (global-set-key (kbd "C-c i u") #'picgo-upload-image-at-point)
  ;; (global-set-key (kbd "C-c i b") #'picgo-batch-upload-images)
  ;; (global-set-key (kbd "C-c i p") #'picgo-upload-clipboard-image)
)
```

## 配置

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

### 自定义设置

自定义PicGo可执行文件的位置：

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
- 链接检测最先检查后缀是否为图片，如果链接或者本地文件不带图片后缀则无法替换上传
- 本地图片请使用全英文路径，emacs中发送shell命令涉及到`utf-8`到`GBK`的转换问题没有进行处理，使用中文路径的话会上传失败
- `org mode`下插入剪切板的图片不会生成描述，只使用`[[url]]`的形式
- `markdown`下不会识别`[description](url)`形式的链接
- 请勿在同一行中写入多个图片链接，否则第二个图片链接及以后无法正常上传

## 许可

本插件采用MIT许可证。 