# 26科协第一次培训 PPT —— Slidev 静态构建产物（dist/）的 nginx 站点镜像
#
# 构建：docker build -t c-ide-training-ppt:latest .
# 运行：docker run -d -p 8099:80 --name c-ide-training-ppt c-ide-training-ppt:latest
# 访问：http://localhost:8099/

# 基础镜像可覆盖：Coolify 服务器拉不到 Docker Hub 时，在
# Advanced > Build > Build arguments 里传
#   NGINX_IMAGE=docker.m.daocloud.io/library/nginx:1.27-alpine
ARG NGINX_IMAGE=nginx:1.27-alpine
FROM ${NGINX_IMAGE}

LABEL org.opencontainers.image.title="c-ide-training-ppt" \
      org.opencontainers.image.description="C语言集成开发环境与编译工具链导论 - 26科协第一次技术培训课件" \
      org.opencontainers.image.version="1.0.0"

# 用项目自己的 SPA 配置替换默认站点（Slidev 使用前端路由：/1、/2 ...）
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/app.conf

# 只需要静态产物，源码（slides.md / node_modules）不进入镜像
COPY dist/ /usr/share/nginx/html/

# dist 里有个别文件是 600（例如 cover.svg），nginx worker 用户读不到会直接 403，
# 所以统一补上「全局可读 + 目录可进入」权限（a+rX 不会给普通文件加执行位）
RUN chmod -R a+rX /usr/share/nginx/html

EXPOSE 80

# nginx:alpine 自带 busybox wget，用它做健康检查，不额外装 curl
HEALTHCHECK --interval=30s --timeout=3s --start-period=3s --retries=3 \
  CMD wget -q --spider http://127.0.0.1/ || exit 1

# 让 docker stop 走 nginx 的 graceful shutdown
STOPSIGNAL SIGQUIT
