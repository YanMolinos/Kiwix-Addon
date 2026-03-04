FROM ghcr.io/kiwix/kiwix-serve:3.8.2

# Add-on launcher / Inicializador do add-on
COPY run.sh /run.sh
COPY zims/ /opt/kiwix/zims/
RUN chmod a+x /run.sh

CMD ["/run.sh"]
