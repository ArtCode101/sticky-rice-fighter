# Project Structure for Java Spring Boot

```text
my-service/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/example/myservice/
│   │   │       ├── MyServiceApplication.java
│   │   │       │
│   │   │       ├── config/
│   │   │       │   ├── DatabaseConfig.java
│   │   │       │   ├── RedisConfig.java
│   │   │       │   ├── KafkaConfig.java
│   │   │       │   └── SftpConfig.java
│   │   │       │
│   │   │       ├── controller/
│   │   │       ├── service/
│   │   │       ├── repository/
│   │   │       ├── entity/
│   │   │       ├── dto/
│   │   │       ├── mapper/
│   │   │       ├── exception/
│   │   │       ├── security/
│   │   │       │
│   │   │       ├── kafka/
│   │   │       │   ├── producer/
│   │   │       │   │   └── EventProducer.java
│   │   │       │   └── consumer/
│   │   │       │       └── EventConsumer.java
│   │   │       │
│   │   │       ├── redis/
│   │   │       │   └── RedisService.java
│   │   │       │
│   │   │       └── sftp/
│   │   │           ├── SftpClient.java
│   │   │           └── SftpService.java
│   │   │
│   │   └── resources/
│   │       ├── application.yml
│   │       └── db/
│   │           └── migration/
│   │               └── V1__initial_schema.sql
│   │
│   └── test/
│       └── java/
│           └── com/example/myservice/
│               ├── repository/
│               ├── kafka/
│               ├── redis/
│               └── sftp/
│
├── .mvn/
├── Dockerfile
├── compose.yml
├── mvnw
├── mvnw.cmd
├── pom.xml
└── README.md
```

## Directory and file reference

### Root

| Path | Purpose |
|---|---|
| `.mvn/` | Maven Wrapper support files (wrapper jar/properties). Lets the project build with a pinned Maven version without requiring Maven to be installed on the machine. |
| `mvnw` / `mvnw.cmd` | Maven Wrapper executable scripts for Unix (`mvnw`) and Windows (`mvnw.cmd`). Use these instead of a globally installed `mvn` to guarantee a consistent Maven version across environments. |
| `pom.xml` | Maven Project Object Model. Declares the project's group/artifact/version, the Spring Boot parent/BOM, all dependencies (web, JPA, Kafka, Redis, security, etc.), and build plugins. |
| `Dockerfile` | Instructions to build the container image for this service (base JDK image, copy the built jar, expose port, entrypoint command). |
| `compose.yml` | Docker Compose file for local development — typically spins up the service alongside its infrastructure dependencies (PostgreSQL, Kafka, Redis, etc.) as containers. |
| `README.md` | Human-readable project documentation: what the service does, how to build/run it, and any setup notes. |

### `src/main/java/com/example/myservice/`

| Path | Purpose |
|---|---|
| `MyServiceApplication.java` | The Spring Boot application entry point, annotated with `@SpringBootApplication`. Contains the `main()` method that bootstraps and runs the application. |
| `config/` | Spring `@Configuration` classes that wire up beans and infrastructure clients. |
| `config/DatabaseConfig.java` | Configures the datasource / JPA / transaction manager beans for PostgreSQL. |
| `config/RedisConfig.java` | Configures the Redis connection factory and `RedisTemplate`/cache manager beans. |
| `config/KafkaConfig.java` | Configures Kafka producer/consumer factories, listener container factory, and topic beans. |
| `config/SftpConfig.java` | Configures the SFTP session factory / integration flow used for file transfer. |
| `controller/` | REST controllers (`@RestController`). Exposes HTTP endpoints, handles requests/responses, and delegates business logic to the `service` layer. |
| `service/` | Business logic layer (`@Service`). Orchestrates operations across repositories, external clients, and other services. |
| `repository/` | Spring Data JPA repositories (`@Repository` / `JpaRepository` interfaces). Handles persistence and database queries. |
| `entity/` | JPA entity classes (`@Entity`) that map directly to database tables. |
| `dto/` | Data Transfer Objects — plain objects used to shape data sent to/received from clients (API requests/responses), decoupled from `entity` classes. |
| `mapper/` | Conversion classes/interfaces (e.g. MapStruct or manual mappers) that translate between `entity` and `dto` objects. |
| `exception/` | Custom exception classes and global exception handlers (e.g. `@ControllerAdvice`) for consistent error responses. |
| `security/` | Spring Security configuration and components: authentication/authorization logic, JWT/OAuth2 handling, security filters. |
| `kafka/producer/EventProducer.java` | Publishes messages/events to Kafka topics. |
| `kafka/consumer/EventConsumer.java` | Listens to Kafka topics (`@KafkaListener`) and processes incoming messages/events. |
| `redis/RedisService.java` | Encapsulates read/write/cache operations against Redis, used by the service layer. |
| `sftp/SftpClient.java` | Low-level SFTP client wrapper responsible for connecting to and transferring files over SFTP. |
| `sftp/SftpService.java` | Higher-level service that uses `SftpClient` to implement business operations involving file transfer (upload/download/processing). |

### `src/main/resources/`

| Path | Purpose |
|---|---|
| `application.yml` | Main Spring Boot configuration file — datasource URL/credentials, server port, Kafka/Redis connection settings, logging, feature flags, etc. |
| `db/migration/V1__initial_schema.sql` | Flyway database migration script. Flyway applies files in this folder in version order (`V1__`, `V2__`, ...) to keep the database schema in sync across environments. |

### `src/test/java/com/example/myservice/`

| Path | Purpose |
|---|---|
| `repository/` | Tests for the persistence layer (e.g. `@DataJpaTest`, often with Testcontainers PostgreSQL) verifying repository queries against a real/near-real database. |
| `kafka/` | Tests for Kafka producers/consumers (e.g. with Testcontainers Kafka or embedded Kafka) verifying messages are published/consumed correctly. |
| `redis/` | Tests for Redis-backed services, verifying caching/read-write behavior. |
| `sftp/` | Tests for SFTP client/service logic, verifying file transfer behavior (often against a test/mock SFTP server). |
