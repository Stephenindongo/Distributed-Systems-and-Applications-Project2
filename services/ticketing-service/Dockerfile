FROM ballerina/ballerina:2201.8.5

WORKDIR /app

COPY . .

RUN bal build

EXPOSE 8083

CMD ["bal", "run", "target/bin/ticketing-service.jar"]
