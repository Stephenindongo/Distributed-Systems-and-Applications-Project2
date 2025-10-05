FROM ballerina/ballerina:2201.8.5

WORKDIR /app

COPY . .

RUN bal build

EXPOSE 8081

CMD ["bal", "run", "target/bin/passenger-service.jar"]
