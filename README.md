# Fleet Management System (fmsystem_phx)

This repository contains the backend source code for a high-performance, cloud-native Fleet Management System (FMS). The system is designed for real-time vehicle telemetry data ingestion, storage, processing, and visualization. It's built to handle thousands of concurrent data points per second, ensuring reliability and low latency for modern fleet operations.

This project focuses on the core backend services. The frontend React application can be found in its own repository.

## Key Features

* **High-Throughput Telemetry Ingestion**: A robust API endpoint (`/api/telemetry`) designed to handle high-velocity data from thousands of IoT devices simultaneously.
* **Real-Time Updates**: Utilizes WebSockets (via Phoenix Channels) to push live data to connected clients, enabling real-time vehicle tracking and dashboard updates.
* **Secure Authentication**: Implements JWT-based authentication for all protected API endpoints and WebSocket connections.
* **Core Fleet Management APIs**: Provides RESTful APIs for managing:
    * Vehicles
    * IoT Devices
    * API Authentication Tokens
* **Role-Based Access Control (RBAC)**: Basic authorization distinguishing between `admin` and `user` roles to control access to resources.
* **Time-Series Database**: Leverages TimescaleDB (a PostgreSQL extension) for efficient storage and querying of telemetry data.

## System Architecture

The system is designed with a cloud-native architecture, separating concerns between the frontend, backend, and database.

1.  **Backend (Elixir/Phoenix)**: This repository. A highly concurrent application that serves the API and manages WebSocket connections.
2.  **Database (TimescaleDB/PostgreSQL)**: Stores all relational and time-series data. The schema is designed to link vehicles, IoT devices, and their telemetry efficiently.
3.  **Frontend (React)**: A separate single-page application that consumes the API and displays data in real-time.
4.  **IoT Clients (Python Simulation)**: Scripts to simulate IoT devices sending telemetry data to the backend.

The entire infrastructure is defined using **Terraform** for automated deployment on **Amazon Web Services (AWS)**, utilizing services like EC2, ECS, ALB, S3, and Route 53.

For a detailed visual representation, see the [Infrastructure Diagram](infra_terraform/diagram/ec2_diagram.svg).

## Technology Stack

* **Backend**: Elixir, Phoenix Framework
* **Database**: PostgreSQL with TimescaleDB Extension
* **Infrastructure**: AWS (EC2, ECS, ALB, S3, CloudFront, Route 53)
* **Infrastructure as Code**: Terraform
* **Containerization**: Docker
* **CI/CD**: GitHub Actions, Docker Hub

## Getting Started

To get the backend running locally, you will need Elixir, Phoenix, PostgreSQL, and Docker installed.

1.  **Clone the repository.**
2.  **Install dependencies.**
3.  **Set up the database:**
    * Ensure your local PostgreSQL server is running.
    * Create the development database.
    * Run migrations.
4.  **Configure environment variables:**
    * You will need to create a configuration file for your environment variables. The project expects variables like `DATABASE_URL`, `SECRET_KEY_BASE`, and `JWT_SECRET`.
5.  **Start the Phoenix server.**

The application will be running at `http://localhost:4000`.

## Future Work

* Implement anomaly detection and user notifications for events like high RPM or low fuel.
* Develop a full Python client script for physical IoT hardware.
* Expand API functionality with more granular query parameters and complete all CRUD operations.
* Integrate advanced analytics and reporting modules for historical data analysis.