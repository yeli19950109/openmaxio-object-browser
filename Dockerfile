# 阶段1: 构建前端
FROM node:20-alpine AS builder

WORKDIR /app

# 安装依赖
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# 拷贝源代码并构建
COPY . .
RUN yarn build

# 阶段2: 打包二进制 console
FROM golang:1.23-alpine AS golang-builder

WORKDIR /src

# 安装构建依赖
RUN apk add --no-cache make git bash

COPY . .
RUN make console

# 阶段3: 最终运行镜像
FROM alpine:3.19

WORKDIR /app

# 拷贝编译好的二进制
COPY --from=golang-builder /src/console /usr/local/bin/console
# 拷贝前端构建产物（假设 build 目录存放在 dist）
COPY --from=builder /app/dist /app/dist

EXPOSE 9090

ENTRYPOINT ["console", "server", "--port", "9090"]
