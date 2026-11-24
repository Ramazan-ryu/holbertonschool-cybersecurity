# Topology (as designed)

build-account(CI) --- deploy ---> platform-account
platform-account:
  app-subnet  --(no route)-- analytics-subnet   # private
  cluster(all-namespaces: pod-security ENFORCED)
  grid-telemetry-store  <-- CMK (tightly held) -- telemetry-service only
