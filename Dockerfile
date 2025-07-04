# docker buildx build --platform linux/amd64,linux/arm64 -t xiaoqingyu-server:latest -f Dockerfile .

# 使用官方 Node.js 镜像作为基础镜像
FROM node:20-alpine AS base

# 设置工作目录
WORKDIR /app

# 复制 package.json 和 package-lock.json（如果存在）
COPY package*.json ./

# 安装 pnpm（根据 package.json 中的配置）
RUN npm install -g pnpm

# 开发依赖阶段
FROM base AS deps
RUN pnpm install

# 构建阶段
FROM base AS build
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# 构建应用
RUN pnpm run build

# 生产依赖阶段
FROM base AS prod-deps
RUN pnpm install --prod

# 生产阶段
FROM node:20-alpine AS production

# 安装 curl（用于健康检查）
RUN apk add --no-cache curl

# 创建非 root 用户
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nestjs -u 1001

# 设置工作目录
WORKDIR /app

# 复制生产依赖
COPY --from=prod-deps --chown=nestjs:nodejs /app/node_modules ./node_modules
COPY --from=build --chown=nestjs:nodejs /app/dist ./dist

# 复制 package.json（运行时可能需要）
COPY --chown=nestjs:nodejs package.json ./

# 切换到非 root 用户
USER nestjs

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# 启动应用
CMD ["node", "dist/main"]
