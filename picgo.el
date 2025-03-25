;;; picgo.el --- PicGo integration for Emacs -*- lexical-binding: t; -*-

;;; Commentary:
;; 为Emacs提供PicGo图床集成功能
;; 支持上传本地图片、远程图片和剪贴板图片
;; 支持Org和Markdown格式

;;; Code:

;; ======================================================
;; 工具函数
;; ======================================================

(defgroup picgo nil
  "PicGo integration for Emacs."
  :group 'external
  :prefix "picgo-")

(defcustom picgo-executable "picgo"
  "PicGo CLI可执行文件路径."
  :type 'string
  :group 'picgo)

(defun picgo--is-local-file-p (path)
  "检查PATH是否为本地文件路径."
  (and path
       (not (string-match-p "^https?://" path))
       (not (string-empty-p path))))

(defun picgo--expand-image-path (path)
  "展开PATH图片路径."
  (when path
    (expand-file-name
     (replace-regexp-in-string "^file:" "" path))))

(defun picgo--is-image-url-p (url)
  "检查URL是否为图片链接."
  (when url
    (and (not (string-match-p "\\]\\[" url))  ;; 确保不是org链接的一部分
         (not (string-match-p "\\](" url))    ;; 确保不是markdown链接的一部分
         (not (string-match-p "[\"']" url))   ;; 确保不包含引号
         (not (string-match-p "<.*>$" url))   ;; 确保不是HTML标签
         (or
          ;; 远程URL
          (and (string-match-p "^https?://" url)
               (string-match-p "\\(?:\\.[a-zA-Z]\\{3,4\\}\\)?\\(?:png\\|jpe?g\\|gif\\|svg\\|webp\\)\\(?:[?#].*\\)?$" url))
          ;; 本地文件
          (and (picgo--is-local-file-p url)
               (let ((expanded-path (picgo--expand-image-path url)))
                 (or (and (file-exists-p expanded-path)
                          (string-match-p "\\.\\(?:png\\|jpe?g\\|gif\\|svg\\|webp\\)$" expanded-path))
                     (string-match-p "\\.\\(?:png\\|jpe?g\\|gif\\|svg\\|webp\\)$" url))))))))

(defun picgo--get-buffer-type ()
  "获取当前buffer的类型."
  (cond
   ((derived-mode-p 'org-mode) 'org)
   ((derived-mode-p 'markdown-mode) 'markdown)
   (t 'unknown)))

(defun picgo--format-link (url description link-type)
  "根据LINK-TYPE, URL和DESCRIPTION格式化链接."
  (pcase link-type
    ('org-with-desc
     (format "[[%s][%s]]" url description))
    ('org
     (format "[[%s]]" url))
    ('markdown
     (format "![%s](%s)" (or description "") url))
    (_
     url)))

;; ======================================================
;; PicGo 接口函数
;; ======================================================

(defun picgo--check-installation ()
  "检查picgo是否正确安装."
  (let ((picgo-path (executable-find picgo-executable)))
    (if picgo-path
        (message "找到picgo执行文件：%s" picgo-path)
      (error "未找到picgo命令。请确保已安装PicGo CLI并添加到PATH中"))))

(defun picgo--has-upload-error-p (output)
  "检查PicGo OUTPUT中是否包含错误信息."
  (string-match-p "\\[PicList ERROR\\]:" output))

(defun picgo--extract-uploaded-url (output)
  "从PicGo OUTPUT中提取上传后的URL."
  (when (and (string-match "\\[PicList SUCCESS\\]:\\s-*\n\\(https?://[^\n]+\\)" output)
             (not (string-empty-p (match-string 1 output))))
    (string-trim (match-string 1 output))))

(defun picgo--upload-image (path-or-url)
  "上传图片(PATH-OR-URL支持本地文件和远程URL)."
  (let* ((upload-path (if (picgo--is-local-file-p path-or-url)
                        (picgo--expand-image-path path-or-url)
                      path-or-url))
         (upload-command (format "%s upload \"%s\"" picgo-executable upload-path))
         (temp-buffer (generate-new-buffer " *picgo-temp*"))
         exit-code
         output)
    (message "正在上传图片: %s" upload-path)
    (unwind-protect
        (progn
          (setq exit-code
                (call-process-shell-command
                 upload-command nil temp-buffer nil))
          (with-current-buffer temp-buffer
            (setq output (buffer-string))))
      (kill-buffer temp-buffer))
    (list exit-code output)))

(defun picgo--upload-clipboard ()
  "上传剪贴板图片."
  (let* ((upload-command (format "%s upload" picgo-executable))
         (temp-buffer (generate-new-buffer " *picgo-temp*"))
         exit-code
         output)
    (message "正在上传剪贴板图片...")
    (unwind-protect
        (progn
          (setq exit-code
                (call-process-shell-command
                 upload-command nil temp-buffer nil))
          (with-current-buffer temp-buffer
            (setq output (buffer-string))))
      (kill-buffer temp-buffer))
    (list exit-code output)))

;; ======================================================
;; 链接解析与生成
;; ======================================================

(defun picgo--find-markdown-img-links-in-line (line line-start)
  "在MARKDOWN模式下, 在LINE中查找图片链接, LINE-START为行起始位置."
  (let ((md-img-regexp "!\\[\\([^]]*\\)\\](\\([^)]+?\\))")
        (start 0)
        links)
    (while (string-match md-img-regexp line start)
      (let* ((match-start (+ line-start (match-beginning 0)))
             (match-end (+ line-start (match-end 0)))
             (url (match-string 2 line))
             (desc (match-string 1 line)))
        ;; 确保我们找到的URL是完整的，不是另一个链接的一部分
        (when (and url 
                   (not (string-match-p "\\](" url))
                   (or (string-match-p "^https?://" url)
                       (string-match-p "^[~/]" url)
                       (string-match-p "^[A-Za-z]:" url)
                       (string-match-p "^\\." url)))
          (push (list match-start match-end url desc 'markdown) links))
        (setq start (match-end 0))))
    (nreverse links)))

(defun picgo--find-org-links-in-line (line line-start)
  "在ORG模式下, 在LINE中查找链接, LINE-START为行起始位置."
  (let ((org-regexp "\\[\\[\\([^]]+\\)\\]\\(?:\\[\\([^]]+\\)\\]\\)?\\]")
        (start 0)
        links)
    (while (string-match org-regexp line start)
      (let* ((match-start (+ line-start (match-beginning 0)))
             (match-end (+ line-start (match-end 0)))
             (url (match-string 1 line))
             (desc (match-string 2 line))
             (link-type (if desc 'org-with-desc 'org)))
        ;; 只保留图片链接
        (when (and url (picgo--is-image-url-p url))
          (push (list match-start match-end url desc link-type) links))
        (setq start (match-end 0))))
    (nreverse links)))

(defun picgo--find-image-link-at-point ()
  "查找当前点下的图片链接."
  (let* ((buffer-type (picgo--get-buffer-type))
         (line-start (line-beginning-position))
         (line-end (line-end-position))
         (line (buffer-substring-no-properties line-start line-end))
         (point-offset (- (point) line-start))
         links
         result)
    ;; 根据buffer类型选择解析方法
    (setq links 
          (pcase buffer-type
            ('markdown (picgo--find-markdown-img-links-in-line line line-start))
            ('org (picgo--find-org-links-in-line line line-start))
            (_ nil)))
    
    ;; 查找当前点所在的链接
    (setq result
          (cl-find-if (lambda (link)
                       (let ((start (nth 0 link))
                             (end (nth 1 link)))
                         (<= start (point) end)))
                     links))
    
    ;; 如果找到链接，检查是否是图片
    (when (and result (picgo--is-image-url-p (nth 2 result)))
      result)))

(defun picgo--find-all-image-links-in-buffer ()
  "查找Buffer中的所有图片链接."
  (let ((buffer-type (picgo--get-buffer-type))
        (links '()))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let* ((line-start (line-beginning-position))
               (line-end (line-end-position))
               (line (buffer-substring-no-properties line-start line-end))
               (line-links 
                (pcase buffer-type
                  ('markdown (picgo--find-markdown-img-links-in-line line line-start))
                  ('org (picgo--find-org-links-in-line line line-start))
                  (_ nil))))
          
          ;; 添加行中找到的所有链接
          (setq links (append line-links links))
          
          (forward-line 1))))
    (nreverse links)))

;; ======================================================
;; 交互命令
;; ======================================================

;;;###autoload
(defun picgo-upload-image-at-point ()
  "上传当前点下的图片链接到图床并替换."
  (interactive)
  (picgo--check-installation)
  (let ((link (picgo--find-image-link-at-point)))
    (if link
        (let* ((start (nth 0 link))
               (end (nth 1 link))
               (url (nth 2 link))
               (desc (nth 3 link))
               (link-type (nth 4 link))
               (original-link (buffer-substring-no-properties start end)))
          
          (let* ((upload-result (picgo--upload-image url))
                 (exit-code (nth 0 upload-result))
                 (output (nth 1 upload-result))
                 (has-error (picgo--has-upload-error-p output))
                 (new-url (and (not has-error)
                              (picgo--extract-uploaded-url output))))
            
            (if (and (= exit-code 0) new-url (not has-error))
                (progn
                  (let ((new-link (picgo--format-link new-url desc link-type)))
                    (save-excursion
                      (goto-char start)
                      (delete-region start end)
                      (insert new-link))
                    (message "图片上传成功: %s" new-url)))
              (message "上传失败: %s" 
                       (if has-error
                           (progn
                             (string-match "\\[PicList ERROR\\]: \\(.*\\)" output)
                             (match-string 1 output))
                         output)))))
      (message "当前位置没有图片链接"))))

;;;###autoload
(defun picgo-batch-upload-images ()
  "批量上传当前buffer中的所有图片链接."
  (interactive)
  (picgo--check-installation)
  (let ((links (picgo--find-all-image-links-in-buffer))
        (processed-links (make-hash-table :test 'equal))
        (total 0)
        (success 0)
        (failed 0))
    
    ;; 按照位置从后向前排序链接，这样替换时不会影响后面链接的位置
    (setq links (sort links (lambda (a b) (> (car a) (car b)))))
    
    (dolist (link links)
      (let* ((start (nth 0 link))
             (end (nth 1 link))
             (url (nth 2 link))
             (desc (nth 3 link))
             (link-type (nth 4 link))
             (original-link (buffer-substring-no-properties start end)))
        
        ;; 检查链接是否已处理过
        (unless (gethash original-link processed-links)
          ;; 确认这是一个有效的图片URL
          (when (picgo--is-image-url-p url)
            (setq total (1+ total))
            (let* ((upload-result (picgo--upload-image url))
                   (exit-code (nth 0 upload-result))
                   (output (nth 1 upload-result))
                   (has-error (picgo--has-upload-error-p output))
                   (new-url (and (not has-error)
                                (picgo--extract-uploaded-url output))))
              
              (if (and (= exit-code 0) new-url (not has-error))
                  (progn
                    (let ((new-link (picgo--format-link new-url desc link-type)))
                      (save-excursion
                        (goto-char start)
                        (let ((current-link (buffer-substring-no-properties start end)))
                          (when (string= original-link current-link)
                            (delete-region start end)
                            (goto-char start)
                            (insert new-link)
                            (setq success (1+ success)))))))
                (setq failed (1+ failed)))))
          
          ;; 标记链接为已处理
          (puthash original-link t processed-links))))
    
    (message "批量上传完成：共处理 %d 个图片链接，成功 %d 个，失败 %d 个" 
             total success failed)))

;;;###autoload
(defun picgo-upload-clipboard-image (&optional description)
  "上传剪贴板中的图片并在当前位置插入链接.
如果提供了DESCRIPTION参数，将使用它作为图片描述；否则会提示输入（仅在markdown模式下）."
  (interactive)
  (picgo--check-installation)
  (let* ((buffer-type (picgo--get-buffer-type))
         ;; 在org模式下不使用描述，在markdown模式下询问
         (desc (cond 
                ((eq buffer-type 'org) nil)
                (description description)
                (t (read-string "输入图片描述(可选): " "img"))))
         (upload-result (picgo--upload-clipboard))
         (exit-code (nth 0 upload-result))
         (output (nth 1 upload-result))
         (has-error (picgo--has-upload-error-p output))
         (new-url (and (not has-error)
                     (picgo--extract-uploaded-url output))))
    
    (if (and (= exit-code 0) new-url (not has-error))
        (let ((new-link (if (eq buffer-type 'org)
                           (format "[[%s]]" new-url)
                         (picgo--format-link new-url desc buffer-type))))
          (insert new-link)
          (message "剪贴板图片上传成功: %s" new-url))
      (message "剪贴板图片上传失败: %s" 
               (if has-error
                   (progn
                     (string-match "\\[PicList ERROR\\]: \\(.*\\)" output)
                     (match-string 1 output))
                 output)))))

(provide 'picgo)
;;; picgo.el ends here
