一个本地代理工具，主要为本地调试flutter web服务。

# dart-proxy-server

* 安装dart sdk >=2.6.4版本或者flutter（自带dart版本需要>=2.6.4）
* cd bin ,执行 dart compile exe dart_proxy_server.dart -o dart-proxy-server-intel-mac，编译可执行程序
* 目前不支持交叉编译，因此需要在对应平台进行编译。

# 启动顺序说明

* 先启动本地代理服务

      [root@master ~]# ./dart-proxy-server-intel-mac -t https://appdev.myones.net -p 3000

        https://appdev.myones.net 的本地代理地址是 http://localhost:3000

* 再启动flutter web服务

      [root@master ~]#  flutter run -d chrome --web-renderer html -t lib/main_dev.dart

 
