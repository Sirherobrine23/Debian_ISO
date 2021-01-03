# Imagem de contêiner que executa seu código
FROM ubuntu:latest
USER root
RUN apt update 
ENV DEBIAN_FRONTEND=noninteractive
RUN apt install git wget curl -y
RUN apt update
RUN apt list --upgradable -a
RUN apt upgrade -y
RUN apt install -y binutils debootstrap squashfs-tools xorriso dosfstools grub-pc-bin jq grub-efi-amd64-bin zip unzip screen mtools nginx
RUN wget "https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip" -O /tmp/nk.zip
RUN unzip -o /tmp/nk.zip -d /usr/bin/
RUN mkdir -p /home/iso
WORKDIR /home/iso

COPY chroot_script/ /home/iso/
RUN if [ -e /home/iso/pre.sh ];then echo Sucess;else exit 1;fi

COPY scripts/ /intallers/
RUN chmod 777 /intallers/*
RUN chmod a+x /intallers/*
RUN bash /intallers/depe.sh

EXPOSE 80

# Arquivo de código a ser executado quando o contêiner do docker é iniciado (`entrypoint.sh`)
ENTRYPOINT ["/intallers/iso.sh"]