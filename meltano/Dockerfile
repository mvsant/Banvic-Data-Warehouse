FROM meltano/meltano:latest-slim


WORKDIR /project

COPY . .

RUN meltano install


CMD ["meltano", "--version"]
