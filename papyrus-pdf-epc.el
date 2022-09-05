;; -*- lexical-binding: t; -*-

(load-file "/home/dalanicolai/git/emacs-scrap/scrap.el")
(load-file "/home/dalanicolai/git/emacs-mupdf/mupdf.el")
(load-file "/home/dalanicolai/git/pymupdf-epc/pymupdf-epc-client.el")
(load-file "/home/dalanicolai/git/emacs-poppler/poppler.el")

(defvar-local pymupdf-epc-server nil)

(defun papyrus-pymupdf-image-data (page _)
  (nth (1- page) scrap-page-images))

(defun papyrus-pdf-epc-svg-embed-base64 (svg data image-type &rest args)
  "Insert IMAGE into the SVG structure.
IMAGE should be a file name if DATAP is nil, and a binary string
otherwise.  IMAGE-TYPE should be a MIME image type, like
\"image/jpeg\" or the like."
  (svg--append
   svg
   (dom-node
    'image
    `((xlink:href . ,(concat "data:" image-type ";base64," data))
      ,@(svg--arguments svg args)))))

(define-derived-mode papyrus-pymupdf-mode special-mode "Papyrus-MuPDF"
  (setq pymupdf-epc-server (epc:start-epc "python" '("pymupdf-epc-server.py")))
  (pymupdf-epc-init)

  (mupdf-create-pages)

  (scrap-minor-mode)

  (setq-local scrap-internal-page-sizes (pymupdf-epc-page-sizes)
              scrap-last-page (length scrap-internal-page-sizes)
              scrap-structured-contents (poppler-structured-contents nil nil t)

               ;; scrap-display-page-function #'papyrus-djvu-display-page
               scrap-image-type 'png
               ;; scrap-image-data-function #'mupdf-get-image-data
               ;; scrap-image-data-function #'pymupdf-epc-page-base64-image-data
               scrap-image-data-function #'papyrus-pymupdf-image-data

               imenu-create-index-function #'papyrus-pymupdf--imenu-create-index
               imenu-default-goto-function (lambda (_name position &rest _rest)
                                             ;; NOTE VERY WEIRD, the first
                                             ;; result is a number, while the
                                             ;; other results are markers
                                             (scrap-goto-page (if (markerp position)
                                                                  (marker-position position)
                                                                position)))
               scrap-info-function #'pymupdf-epc-info))

(defun pymupdf--imenu-recur ()
  (let ((level (caar scrap-imenu-index))
        sublist)
    (while (and (cdr scrap-imenu-index)
                (>= (car (nth 1 scrap-imenu-index)) level))
      (let* ((e (car scrap-imenu-index))
             (title (nth 1 e))
             (page (nth 2 e)))
        (cond ((= (car (nth 1 scrap-imenu-index)) level)
               (push (cons title page) sublist)
               (setq scrap-imenu-index (cdr scrap-imenu-index)))
              ((> (car (nth 1 scrap-imenu-index)) level)
               (setq scrap-imenu-index (cdr scrap-imenu-index))
               (push (append (list title) (pymupdf--imenu-recur))
                     sublist)))))
    (when (= (car (car scrap-imenu-index)) level)
      (let ((e (car scrap-imenu-index)))
        (push (cons (nth 1 e) (nth 2 e)) sublist)))
    (when (and (cdr scrap-imenu-index) (<= (- level (car (nth 1 scrap-imenu-index))) 1))
      (setq scrap-imenu-index (cdr scrap-imenu-index)))
    (nreverse sublist)))

(defun papyrus-pymupdf--imenu-create-index ()
  (setq scrap-imenu-index (pymupdf-epc-toc))
  (pymupdf--imenu-recur))

;; (setq papyrus-mupdf-mode-map scrap-mode-map)
;; (defun papyrus-pymupdf--imenu-create-index ()
;;   (let ((outline (pymupdf-epc-toc)))
;;     (with-current-buffer (get-buffer-create "*outline*")
;;       (erase-buffer)
;;       (let ((level 0))
;;         (insert "((" (format "%S . %d" (cadar outline) (cadr (cdar outline))))
;;         (dolist (e (cdr outline))
;;           (cond ((= (car e) level)
;;                  (insert ") (" (format "%S . %d" (nth 1 e) (caddr e))))
;;                 ((> (car e) level)
;;                  (while (not (looking-back "\\."))
;;                    (delete-char -1))
;;                  (delete-char -1)
;;                  (insert " (" (format "%S . %d" (nth 1 e) (caddr e))))
;;                 ((< (car e) level)
;;                  (dotimes (_ (1+ (- level (car e))))
;;                    (insert ")"))
;;                  (insert " (" (format "%S . %d" (nth 1 e) (caddr e)))))
;;           (setq level (car e)))
;;         (dotimes (_ (+ level 2))
;;           (insert ")")))
;;       (goto-char (point-min))
;;       (setq test (read (current-buffer))))))

  (add-to-list 'auto-mode-alist '("\\.pdf\\'" . papyrus-pymupdf-mode))
