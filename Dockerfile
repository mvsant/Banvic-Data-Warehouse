FROM meltano/meltano:latest-slim


WORKDIR /project


COPY meltano.yml .


RUN meltano install


CMD ["meltano", "--version"]
