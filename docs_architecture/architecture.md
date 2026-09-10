                         ┌───────────────────────────┐
                         │          USERS            │
                         │                           │
                         │  👨‍🌾 Farmer   🏛️ Official │
                         └─────────────┬─────────────┘
                                       │
                                       ▼
                         ┌───────────────────────────┐
                         │        FRONTEND           │
                         │      Flutter Apps         │
                         │                           │
                         │ ┌───────────────────────┐ │
                         │ │ Farmer Android App    │ │
                         │ │ • Registration        │ │
                         │ │ • Verification        │ │
                         │ │ • Appointment         │ │
                         │ │ • Queue               │ │
                         │ │ • Travel              │ │
                         │ │ • MSP                 │ │
                         │ │ • Procurement Status  │ │
                         │ │ • Payment             │ │
                         │ │ • Assistant           │ │
                         │ └───────────────────────┘ │
                         │                           │
                         │ ┌───────────────────────┐ │
                         │ │ Government Android App│ │
                         │ │ • Dashboard           │ │
                         │ │ • Farmer Management   │ │
                         │ │ • Verification Status │ │
                         │ │ • Centre Management   │ │
                         │ │ • Queue Monitoring    │ │
                         │ │ • Procurement Updates │ │
                         │ │ • Payments            │ │
                         │ └───────────────────────┘ │
                         └─────────────┬─────────────┘
                                       │
                                       ▼
                         ┌───────────────────────────┐
                         │      BACKEND / API        │
                         │        Supabase           │
                         │                           │
                         │ • Authentication          │
                         │ • PostgreSQL Database     │
                         │ • RPC / Business Logic    │
                         │ • Realtime Engine         │
                         │ • Notification Handling   │
                         │ • Data Validation         │
                         └───────┬───────────┬───────┘
                                 │           │
                    ┌────────────┘           └─────────────┐
                    ▼                                      ▼
       ┌────────────────────────┐             ┌────────────────────────┐
       │        DATABASE        │             │    REALTIME SYNC       │
       │      PostgreSQL        │             │                        │
       │                        │             │ Government ↔ Farmer    │
       │ • Farmers              │             │ live updates           │
       │ • Verification         │             │                        │
       │ • Appointments         │             │ • Queue                │
       │ • Farmer Status        │             │ • Attendance           │
       │ • Centres              │             │ • Procurement          │
       │ • Queue Status         │             │ • Centre Assignment    │
       │ • Procurement          │             │ • Payment Status       │
       │ • Payments             │             │ • Notifications        │
       │ • Notifications        │             └────────────────────────┘
       │ • Activity History     │
       │ • Government Users     │
       └────────────┬───────────┘
                    │
                    ▼
       ┌────────────────────────────────────────┐
       │       INTELLIGENCE / ML LAYER          │
       │                                        │
       │  Historical procurement data           │
       │            │                           │
       │            ▼                           │
       │  Processing-time prediction            │
       │            │                           │
       │            ▼                           │
       │  Farmer-level estimated time           │
       │            │                           │
       │            ▼                           │
       │  Slot workload prediction              │
       │            │                           │
       │            ▼                           │
       │  Centre load / bottleneck prediction   │
       │            │                           │
       │            ▼                           │
       │  Smart centre allocation               │
       └───────────────────┬────────────────────┘
                           │
                           ▼
               ┌────────────────────────────┐
               │     PREDICTION / RESULT    │
               │                            │
               │ • Estimated processing     │
               │   time per farmer          │
               │ • Queue waiting time       │
               │ • Slot workload            │
               │ • Centre load %            │
               │ • Bottleneck detection     │
               │ • Recommended centre       │
               │ • Estimated service time   │
               │ • Travel / leave time      │
               └──────────────┬─────────────┘
                              │
                              ▼
                    ┌────────────────────────┐
                    │       FRONTEND         │
                    │                        │
                    │ Farmer sees:           │
                    │ • Appointment          │
                    │ • Queue ETA            │
                    │ • Travel recommendation│
                    │ • Procurement status   │
                    │ • Payment status       │
                    │                        │
                    │ Government sees:       │
                    │ • Centre load          │
                    │ • Bottlenecks          │
                    │ • Queue                │
                    │ • Farmer status        │
                    │ • Allocation decisions │
                    └────────────────────────┘