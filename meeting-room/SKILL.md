---
name: meeting-room
description: 在 Ubuntu 上执行会议室会议纪要脚本：启动会议、停止会议、查看状态、抓取日志，并在 stop 后自动等待 diarization 和生成 summary。适用于用户要求“开始会议纪要”“停止会议纪要”“查看会议状态”“运行会议室脚本”。
---

# Meeting Room

Use this skill when the user wants to run the meeting-room launcher workflow on this machine.

## Canonical Commands

The main entrypoint is:

```bash
bash /home/ivan/github/diarization/scripts/meeting_room.sh {start|stop|status}
```

Meaning:

- `start`: check ASR, start `meeting-recorder`, then start the meeting
- `stop`: stop the meeting, wait for diarization, then auto-generate default summary
- `status`: print recorder status, latest meeting directory, and recent logs

## Expected Outputs

- Recordings are written under:
`/home/ivan/github/meetings/recordings/YYYY-MM-DD/*_meeting`
- Packaged meeting artifacts are written under:
`/home/ivan/Documents/meeting_minutes_packages`

## Preferred Workflow

1. Start:
   ```bash
   bash /home/ivan/github/diarization/scripts/meeting_room.sh start
   ```
2. Stop:
   ```bash
   bash /home/ivan/github/diarization/scripts/meeting_room.sh stop
   ```
3. Status or diagnostics:
   ```bash
   bash /home/ivan/github/diarization/scripts/meeting_room.sh status
   ```

## Notes

- If the user wants one-click launchers, they are installed via:
  `/home/ivan/github/diarization/scripts/install_meeting_room_shortcuts.sh`
- Ubuntu app search entries are named:
  `Meeting Start`, `Meeting Stop`, `Meeting Status`
- If transcript quality is poor, check whether the active microphone is the default input device.
