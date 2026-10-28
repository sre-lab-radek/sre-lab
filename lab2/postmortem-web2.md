## Timeline (UTC, local time in parentheses)
- 15:26 (16:26) Graceful shutdown of web2 initiated (simulated failure)
- 15:27 (16:27) Last metrics sample from web2
- 15:28 (16:28) InstanceDown alert firing, about 2 min after shutdown
- 15:29 (16:29) web2 started again
- 15:29:30 (16:29:30) Metrics resumed, alert resolved