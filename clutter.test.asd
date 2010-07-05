(asdf:defsystem clutter.test
  :version "0"
  :description "Test cases for Clutter"
  :maintainer "Josh Marchán <sykopomp@Dagon>"
  :author "Josh Marchán <sykopomp@Dagon>"
  :licence "MIT"
  :depends-on (clutter eos)
  :components
  ((:module "test"
            :serial t
            :components
            ((:file "test")
             (:file "reader")
             (:file "environments")
             (:file "functions")
             (:file "primitives")
             (:file "eval")))))


