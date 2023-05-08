一个本地代理工具，主要为本地调试flutter web服务。

# dart-proxy-server

* 安装dart sdk >=2.6.4版本或者flutter（自带dart版本需要>=2.6.4）
* cd bin ,执行 dart compile exe dart_proxy_server.dart -o dart-proxy-server-intel-mac，编译可执行程序
  *目前不支持交叉编译，因此需要在对应平台运行该编译器。

# example

[root@master ~]# ./dart-proxy-server-intel-mac -t https://appdev.myones.net -p 3000

```
https://appdev.myones.net 的本地代理地址是 http://localhost:3000
 
