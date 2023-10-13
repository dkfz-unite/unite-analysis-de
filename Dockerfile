FROM ubuntu:latest as base
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get install -y r-base-dev

FROM base as install
COPY ./src /src
WORKDIR /src
RUN apt-get install -y libcurl4-openssl-dev libssl-dev libxml2-dev
RUN Rscript install.R
RUN apt-get clean

FROM install as final
COPY ./app /app
WORKDIR /app
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
ENV ASPNETCORE_hostBuilder:reloadConfigOnChange=false
ENV UNITE_COMMAND="Rscript"
ENV UNITE_COMMAND_ARGUMENTS="run.R {data}/{proc}_data.tsv {data}/{proc}_metadata.tsv {data}/{proc}_results.tsv"
ENV UNITE_SOURCE_PATH="/src"
ENV UNITE_DATA_PATH="/mnt/analysis"
ENV UNITE_LIMIT="5"
EXPOSE 80
CMD ["/app/Unite.Commands.Web", "--urls", "http://0.0.0.0:80"]