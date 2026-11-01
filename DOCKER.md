# 用 Docker 跑这份 PPT

把 Slidev 的静态构建产物 `dist/` 打成一个 nginx 镜像，任何装了 Docker 的机器上一条命令就能放出来。

- 基础镜像：`nginx:1.27-alpine`
- 镜像大小：约 80 MB（产物 4.6 MB）
- 默认端口：容器内 `80` → 宿主机 `8099`（沿用原来 `run.sh` 的端口习惯）

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `Dockerfile` | 基于 nginx 的静态站点镜像，只拷 `dist/` |
| `nginx.conf` | SPA 回退（`/3`、`/12` 这类路由）、静态资源长缓存、gzip、`/healthz` |
| `.dockerignore` | 排除 `node_modules/`、`ide-training/`、`*.bak` 等，构建上下文只剩 ~5 MB |
| `docker-compose.yml` | 起服务用，端口 8099 |
| `README.md` | 仓库首页说明 |
| `.github/workflows/pages.yml` | GitHub Pages 构建 + 部署 |

## GitHub Pages

仓库已开启 Pages（Source = **GitHub Actions**），地址：

<https://yetongy.github.io/sipc-1st-ide-ppt/>

要点：项目页挂在子路径 `/sipc-1st-ide-ppt/` 下，而 `dist/` 里的资源是绝对根路径 `/assets/...`（给 Docker / Coolify 用），**两者不能共用一份产物**。所以 Pages 由 [.github/workflows/pages.yml](.github/workflows/pages.yml) 在 CI 里重新构建，带 `--base /sipc-1st-ide-ppt/`，输出到 `dist-pages/`（已 gitignore，不入库）。

- 改 `slides.md` → push → 自动重新部署；也可以在 Actions 页面手动 `Run workflow`。
- 深链接（如 `/sipc-1st-ide-ppt/7`）依赖 Slidev 生成的 `404.html`：它和 `index.html` 是同一份 app shell，Pages 对未知路径返回它（404 状态码），前端路由接管后正常显示那一页。这也是为什么 `dist/_redirects` 之外还需要它。
- 本地复现 Pages 效果：

  ```bash
  pnpm exec slidev build --base /sipc-1st-ide-ppt/ --out dist-pages
  ```

## 部署到 Coolify

Coolify **没有**「上传文件夹 / 上传 tar」的入口。`+ New` 里能选的只有：Git 仓库、已发布到 registry 的镜像、以及粘贴在 UI 里的 Dockerfile。所以只有两条路：

### 路线 A：Git 仓库 + Dockerfile（推荐，push 即部署）

不需要在本机打镜像，Coolify 在服务器上 `docker build`，几秒钟完成。

1. 本目录直接当仓库（`.gitignore` 已排除 `node_modules/`，仓库约 4.7 MB）：

   ```bash
   cd "/home/yetongy/Documents/第一次培训/PPT"
   git init -b main && git add -A && git commit -m "feat: 26科协第一次培训 PPT + nginx 镜像"
   git remote add origin <你的仓库地址>
   git push -u origin main
   ```

2. Coolify → 项目 → `+ New` → 选 Git 源（public URL / Deploy Key / GitHub App / GitLab App）
3. **Build pack** 选 `Dockerfile`
   - Base Directory：`/`
   - Dockerfile Location：`/Dockerfile`
4. **General** 里：

   | 字段 | 填什么 |
   | --- | --- |
   | Ports Exposes | `80` |
   | Domains | `https://ppt.你的域名` |
   | Healthcheck Path | `/healthz`（可选，镜像自带 HEALTHCHECK） |

5. Deploy。之后开了 Automatic Deployment 就是 `git push` 即更新。

服务器拉不到 Docker Hub 时，在 **Advanced > Build > Build arguments** 传：

```
NGINX_IMAGE=docker.m.daocloud.io/library/nginx:1.27-alpine
```

### 路线 B：推镜像 + Coolify「Docker Image」

本机已经打好 `c-ide-training-ppt:latest`（`linux/amd64`，79.8 MB），推到 Coolify 服务器能访问的 registry：

```bash
cd "/home/yetongy/Documents/第一次培训/PPT"
docker build -t <REGISTRY>/<GROUP>/ppt:v1 .
docker login <REGISTRY>                      # 私有库
docker push <REGISTRY>/<GROUP>/ppt:v1
```

Coolify → `+ New` → **Docker Image**：

| 字段 | 填什么 |
| --- | --- |
| Image Name | `<REGISTRY>/<GROUP>/ppt` |
| Tag | `v1`（别只写 `latest`，回滚时认不出内容） |
| Ports Exposes | `80` |
| Domains | `https://ppt.你的域名` |

注意：

- 每台要拉镜像的服务器都得先 `docker login`（Coolify 里是 **Settings → Docker registries** / 服务器级认证），否则部署时报 `pull access denied`。
- registry 是自签 HTTPS 或用 80/非标准端口时，服务器上需要配 `insecure-registries` 或 CA，Coolify 本身不改这个。
- 服务器架构要和镜像一致（本机是 `x86_64`；如果是 arm 服务器，加 `--platform linux/arm64` 重新 build）。
- 镜像更新后要在 Coolify 里 **Redeploy / Restart**，`latest` 这种可变 tag 才会重新拉取。

### 为什么不用另外两个选项

- **Dockerfile（不带 Git）**：Coolify 只保存 Dockerfile 文本，**没有构建上下文**，`COPY dist/` 直接失败。要走这条只能把产物打成 tar 放公网 URL 再 `ADD <url>`，等于多一道上传，不划算。
- **Docker Compose（不带 Git）**：同样没有上下文，只能引用现成镜像；而且 `docker-compose.yml` 里的 `ports: 8099:80` 会和 Traefik 抢端口。Coolify 里跑这份 compose 没有收益。

## 最常用：compose 起服务

```bash
cd "/home/yetongy/Documents/第一次培训/PPT"
docker compose up -d --build     # 构建 + 启动
# 打开 http://localhost:8099/ （局域网用本机 IP:8099）
docker compose logs -f           # 看访问日志
docker compose down              # 停掉并删除容器
```

## 纯 docker 命令

```bash
docker build -t c-ide-training-ppt:latest .
docker run -d --name c-ide-training-ppt -p 8099:80 --restart unless-stopped c-ide-training-ppt:latest
```

换端口就把 `-p 8099:80` 前面的数字改掉，例如 `-p 3000:80` → 访问 `http://localhost:3000/`。

## 改了 slides.md 之后

镜像里的内容来自 `dist/`，所以流程是「重新构建静态产物 → 重新打镜像」：

```bash
pnpm build                       # 生成新的 dist/（Slidev）
docker compose up -d --build     # 重新打包并替换容器
```

## 拷到没有网络的机器上

```bash
# 有网的机器
docker save c-ide-training-ppt:latest | gzip > c-ide-training-ppt.tar.gz    # 约 35 MB

# 目标机器
gunzip -c c-ide-training-ppt.tar.gz | docker load
docker run -d -p 8099:80 --name c-ide-training-ppt c-ide-training-ppt:latest
```

## 已经做过的验证

- `/`、`/12` 等前端路由返回 200，SPA 回退正常
- 无扩展名的资源请求不会回退成 HTML（`/assets/xxx.js` 缺失直接 404，避免浏览器把 HTML 当 JS 解析）
- 构建产物带 `Cache-Control: public, max-age=31536000, immutable`，`index.html` 为 `no-cache`
- JS/CSS 命中 gzip
- 容器 `HEALTHCHECK` 为 healthy
- 用无头 Chromium 实机打开 `/7` 并翻过 3 次 click，三张卡片正常渲染

## 已知无关项

`index.html` 里的字体（Google Fonts）和 favicon（jsDelivr）是外链 CDN，完全离线时字体会退回系统字体，幻灯片本身照常播放。要彻底离线可以自己托管字体文件，但那是课件层面的改动，不影响镜像。
