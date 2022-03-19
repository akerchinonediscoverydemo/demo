FROM node:16 as build
WORKDIR /usr/local/app
COPY ./OneDiscoveryDemoUi/OneDiscoveryDemoUi/ /usr/local/app/
RUN npm install
RUN npm run build
FROM nginx:latest
COPY --from=build /usr/local/app/dist/OneDiscoveryDemoUi /usr/share/nginx/html
COPY ./OneDiscoveryDemoUi/nginx.conf /etc/nginx/conf.d/default.conf
CMD ["/bin/sh",  "-c",  "exec nginx -g 'daemon off;'"]
EXPOSE 80