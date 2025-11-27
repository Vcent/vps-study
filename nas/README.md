# 反向代理配置

### 应用场景

局域网中有 NAS，需要对外开放端口，希望有 nginx 转发到localhost 的其他端口。nginx 可以安装在 docker，也可以直接安装到机器上。

### 配置路径

nginx 的默认配置在`/etc/nginx/nginx.conf`,该配置通常会 `include /etc/nginx/config.d`，将本配置拷贝到： `/etc/nginx/config.d`

### docker 环境

docker 环境在，主要宿主机和 docker 的mount 映射，举个例子：宿主机目录是`/var/docker/nginx/config.d`，因此容器启动映射设置如下：`/var/docker/nginx/config.d:/etc/nginx/config.d`

