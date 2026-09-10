# AGRIPROCURE

> A unified digital platform connecting farmers with procurement centers
> to simplify registration, verification, eligibility checking,
> appointment management, and application processing.

## Overview

AGRIPROCURE is a digital procurement-management platform designed to
simplify and organize the interaction between farmers and agricultural
procurement centers. The platform addresses common challenges such as
manual verification, fragmented application tracking, appointment
management, and limited visibility into the progress of procurement
applications.

The system consists of two connected applications that share a common
backend and database. The Farmer App provides farmers with a simple
interface to register, complete verification, manage their procurement
application, view appointments, track progress, and receive updates.
The Procurement Center App provides authorized personnel with tools to
review farmer information, manage the procurement workflow, update
application status, and coordinate the processing of farmer requests.

## Procurement Center Password
Password: procure123

## Project Information
1. Project Title: AGRIPROCURE

2. PS ID: SIH26032

3. PS Title: Farmers often face long waiting times, lack of information regarding procurement
             schedules, and uncertainity about procurement status

4. Category: Software

5. Theme: Smart Automation

## Problem Statement

Farmers often face long waiting times, lack of information regarding procurement schedules and uncertainty about procurement status.

## Proposed Solution

AGRIPROCURE provides a connected digital workflow between farmers and
procurement centers through two dedicated applications backed by a
shared database.

The Farmer App handles registration, verification, eligibility,
appointment information, queue and travel information, procurement
status, payment information, and notifications. The Procurement Center
App allows authorized personnel to view eligible farmers, review their
information, manage procurement stages, and update application status.

The two applications communicate through a centralized backend, allowing
changes made by procurement-center personnel to be reflected in the
corresponding farmer account and allowing relevant farmer-side updates
to be reflected at the procurement center. This provides a consistent
view of the procurement process and reduces dependence on manual
communication and paperwork.

## Objectives

- Simplify access to procurement-related services
- Reduce manual paperwork and processing
- Improve verification and transparency
- Allow farmers to track application progress
- Provide procurement personnel with an organized workflow
- Provide a connected workflow between farmers and procurement centers
- Improve visibility of appointment and queue information
- Support better identification of procurement-center workload and
  potential bottlenecks

## Applications

1. Farmer App

The Farmer App allows farmers to:

- Register and create an account
- Complete verification
- Submit/view land records
- Verify bank account information
- Submit crop and quantity information
- Check eligibility
- Submit applications
- View and manage appointments
- View assigned procurement centers
- Track queue information
- View travel and estimated arrival information
- Track procurement/application status
- View payment information
- Receive important updates and notifications
- Interact with the in-app assistant
- Manage language and profile settings

2. Procurement Center App

The Procurement Center App allows authorized personnel to:

- Access the procurement-center dashboard
- View eligible and assigned farmers
- View farmer application details
- Review land records
- Review verification information
- Review eligibility information
- View crop and expected quantity
- Manage appointments
- Monitor farmer arrival and attendance
- Manage procurement workflow stages
- Update application/procurement status
- View relevant queue and workload information
- Identify potential center workload and bottleneck conditions
- Communicate important updates to farmers

## System Workflow


                 FARMER APP
                     │
                     ▼
              Farmer Registration
                     │
                     ▼
                 Verification
                     │
          ┌──────────┼──────────┐
          ▼          ▼          ▼
     Land Record   Bank       Crop &
                  Account    Quantity
          │          │          │
          └──────────┼──────────┘
                     ▼
              Eligibility Check
                     │
                     ▼
              Application Submit
                     │
                     ▼
          Appointment / Allocation
                     │
                     ▼
        ┌──────────────────────────┐
        │   PROCUREMENT CENTER     │
        │           APP            │
        └──────────────────────────┘
                     │
                     ▼
             Application Review
                     │
                     ▼
             Record Verification
                     │
                     ▼
          Appointment / Farmer Arrival
                     │
                     ▼
            Procurement Processing
                     │
          ┌──────────┼───────────┐
          ▼          ▼           ▼
       Quality     Weighing    Procurement
        Check
                     │
                     ▼
               Bill / Payment
                     │
                     ▼
                Status Update
                     │
                     ▼
                  FARMER APP
                     │
          ┌──────────┼───────────┐
          ▼          ▼           ▼
        Status    Notification  Payment
          │
          ▼
       Completion
