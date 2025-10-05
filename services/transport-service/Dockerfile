FROM ballerina/ballerina:2201.8.5

WORKDIR /app

COPY . .

RUN bal build

EXPOSE 8082

CMD ["bal", "run", "target/bin/transport-service.jar"]
