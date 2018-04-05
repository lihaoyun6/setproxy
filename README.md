# setproxy 一个用于快速设置macOS系统代理的命令行工具

```
macdeMacBook-Pro:~ mac$ setproxy -h
用法: setproxy [-m pac|socks|http|https|off] [-s <PAC文件地址/代理服务器地址>] [-p <端口>]
    -m, --mode                       代理模式, 可以是下列其中之一: pac,socks,http,https,off
    -s, --server                     pac模式下用于设置PAC文件地址, 其他模式中用于设置代理服务器地址
    -p, --port                       设置连接到代理服务器的端口
    -x, --proxy-exception            设置要忽略代理设置的例外域名/地址
    -h, --help                       显示此帮助信息
    -v, --version                    显示版本信息
```
例如  
```
macdeMacBook-Pro:~ mac$ sudo setproxy -m https -s 1.1.1.1 -p 8080
已将代理模式设置为 https
1.1.1.1:8080
```
