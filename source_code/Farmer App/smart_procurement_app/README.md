# Farmer App

A Flutter-based mobile application designed to help farmers access
and manage agricultural procurement services through a single digital platform.

## Overview

The Farmer App provides farmers with a simple platform to register,
verify their details, submit required information, check eligibility, request slot for procurement 
and track the progress of their procurement applications.

## Objectives

- Simplify access to agricultural procurement services
- Reduce unnecessary visits
- Provide transparent application tracking
- Make verification and eligibility information easily accessible

## Key Features

1. Registration
Farmers can register through their Aadhar card number (to make every registration safe and unique).

2. Verification
The application guides the farmer through the verification process
and displays the current verification status.

3. Land Records
APP Shows Farmer Their land records via Fetching Its Details Through Government Database.

4. Eligibility Check
The app allows farmers to check whether they meet the requirements
for the Procurement Service.

5. Application Status
Farmers can track the current status of their submitted procurement application.

6. Appointment
Farmers get automatically scheduled slot for their procurement request. 

7. Notifications
Important updates and status changes are communicated to the farmer.

## Application Workflow

Registration
    ↓
Verification
    ↓
Land Record Verification
    ↓
Eligibility Check
    ↓
Application Submission
    ↓
Appointment / Further Processing
    ↓
Application Status & Updates

## Technology Stack

- Flutter
- Dart
- SupaBase
- PostgreSQL
- APIs: SUPABASE API, OSRM ROUTING API, OpenStreetMap, Android Notification API

## Project Structure

```text
Farmer App/
├── android/
├── ios/
├── web/
├── lib/
│   ├── ...
├── assets/
├── pubspec.yaml
└── README.md