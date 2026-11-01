# 26科协第一次技术培训 · C 语言 IDE 与工具链导论

Slidev 写的培训课件，配套的静态站点镜像（nginx）和部署配置。

**在线预览**

- GitHub Pages：<https://yetongy.github.io/sipc-1st-ide-ppt/>（公开，直接能放）
- Coolify：走同一份 `dist/` 打成 nginx 镜像，见 [DOCKER.md](DOCKER.md)

## 本地开发

```bash
pnpm install
pnpm dev            # http://localhost:3030
```

## 生成静态站点

```bash
pnpm build          # 产物在 dist/，base 为 /（给 Docker / Coolify 用）
```

GitHub Pages 的产物由 CI 自己构建（`--base /sipc-1st-ide-ppt/`），不需要提交。

## Docker / Coolify

```bash
docker compose up -d --build      # http://localhost:8099
```

Coolify 部署（Dockerfile 构建、端口、缓存、私有库认证）见 [DOCKER.md](DOCKER.md)。

## 目录结构

```
slides.md             课件正文（957 行）
components/           自定义 Vue 组件
public/               静态资源
dist/                 已构建的静态站点（base /）
.github/workflows/    GitHub Pages 部署
Dockerfile            nginx:1.27-alpine 静态站点镜像
nginx.conf            SPA 回退 + 长缓存 + gzip
docker-compose.yml    本地 8099 预览
DOCKER.md             部署说明
```

## 许可

课件内容仅供培训使用。
