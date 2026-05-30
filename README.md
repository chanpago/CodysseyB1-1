# CodysseyB1-1

Agent App Linux Mission 구현 파일 모음입니다. 목표는 제공된 `agent-app-linux-x86` 또는 `agent-app-linux-arm64` 바이너리가 Ubuntu 계열 Linux 서버에서 일반 계정으로 실행되도록 운영 환경을 구성하고, Bash 기반 `monitor.sh`로 상태를 기록하는 것입니다.

## 구성

```text
.
├── agent-app/
│   ├── agent-app-linux-arm64
│   └── agent-app-linux-x86
├── bonus/
│   └── report.sh
├── docs/
│   ├── agent_app_linux_mission_implementation.md
│   └── 수행내역서_템플릿.md
└── scripts/
    ├── setup_users_permissions.sh
    ├── setup_firewall_ufw.sh
    ├── install_agent_app.sh
    ├── monitor.sh
    ├── install_cron.sh
    └── verify_all.sh
```

## 고정 설정값

| 항목 | 값 |
| --- | --- |
| Admin user | `agent-admin` |
| Dev user | `agent-dev` |
| Test user | `agent-test` |
| Common group | `agent-common` |
| Core group | `agent-core` |
| AGENT_HOME | `/home/agent-admin/agent-app` |
| Agent port | `15034` |
| SSH port | `20022` |
| Key file | `/home/agent-admin/agent-app/api_keys/t_secret.key` |
| Monitor log | `/var/log/agent-app/monitor.log` |

`t_secret.key` 내용은 다음 한 줄입니다.

```text
agent_api_key_test
```

## 실행 순서

Linux 서버에서 저장소 루트로 이동한 뒤 실행합니다.

```bash
# 1. 계정/그룹/디렉터리/권한 설정
bash scripts/setup_users_permissions.sh

# 2. UFW 방화벽 설정
bash scripts/setup_firewall_ufw.sh

# 3. Agent 앱 설치
bash scripts/install_agent_app.sh

# 4. monitor.sh 설치
sudo cp scripts/monitor.sh /home/agent-admin/agent-app/bin/monitor.sh
sudo chown agent-dev:agent-core /home/agent-admin/agent-app/bin/monitor.sh
sudo chmod 750 /home/agent-admin/agent-app/bin/monitor.sh
```

권한 구조는 `agent-app` 상위 디렉터리를 `agent-common` 그룹으로 열어 `agent-test`가 `upload_files`까지 접근할 수 있게 하고, `api_keys`, `bin`, `/var/log/agent-app`는 `agent-core` 그룹으로 제한합니다.

SSH 보안 설정은 원격 접속 중인 서버에서 세션 유지 여부를 확인한 뒤 적용합니다.

```bash
sudo tee /etc/ssh/sshd_config.d/99-agent-mission.conf >/dev/null <<'EOF'
Port 20022
PermitRootLogin no
EOF
sudo sshd -t
sudo systemctl restart ssh || sudo systemctl restart sshd
```

Agent 앱은 root가 아닌 일반 계정으로 실행합니다.

```bash
sudo -iu agent-admin
source /etc/profile.d/agent-app.sh
/home/agent-admin/agent-app/bin/agent-app
```

다른 터미널에서 모니터링과 cron 등록을 진행합니다.

```bash
# 수동 모니터링 확인
sudo -iu agent-admin /home/agent-admin/agent-app/bin/monitor.sh

# 매분 자동 실행 등록
bash scripts/install_cron.sh

# 전체 검증
bash scripts/verify_all.sh
```

## monitor.sh 기능

- `agent-app` 프로세스 확인
- TCP `15034` LISTEN 확인
- UFW 또는 firewalld 상태 확인
- CPU, MEM, DISK 사용률 수집
- CPU `20%`, MEM `10%`, DISK `80%` 초과 시 `[WARNING]` 출력
- `/var/log/agent-app/monitor.log` 누적 기록
- `monitor.log`가 10MB 이상이면 로테이션
- 최대 `monitor.log.1`부터 `monitor.log.10`까지 10개 보관
- 프로세스 또는 포트 확인 실패 시 `exit 1`
- 방화벽 비활성 및 리소스 임계값 초과는 경고만 출력

## 리포트

누적 로그의 CPU/MEM/DISK 평균, 최대, 최소를 출력합니다.

```bash
bash bonus/report.sh
# 또는
bash bonus/report.sh /var/log/agent-app/monitor.log
```

## 제출 문서

실행 결과 증적은 [docs/수행내역서_템플릿.md](docs/수행내역서_템플릿.md)에 명령 출력과 함께 작성합니다.

작성된 수행내역서는 [docs/수행내역서.md](docs/수행내역서.md)에 정리했습니다.

## 실행 결과 캡처 증적

### 1. Ubuntu 실행 환경

![Ubuntu 실행 환경](chapter/1.ubuntu환경.png)

Ubuntu 22.04.5 LTS, WSL2 커널, `x86_64` 아키텍처를 확인한 화면입니다. `x86_64` 환경이므로 `agent-app-linux-x86` 바이너리를 사용했습니다.

### 2. 계정, 그룹, 디렉터리 권한

![계정 및 권한 확인](chapter/2.permission.png)

`agent-admin`, `agent-dev`, `agent-test` 계정과 `agent-common`, `agent-core` 그룹 멤버십을 확인한 화면입니다. `/home/agent-admin/agent-app`, `upload_files`, `api_keys`, `bin`, `/var/log/agent-app`, 키 파일 권한도 함께 확인했습니다.

### 3. Agent 앱 설치

![Agent 설치 확인](chapter/3.agent_install.png)

Agent 바이너리가 `/home/agent-admin/agent-app/bin/agent-app`에 설치되었고, 소유자/그룹이 `agent-dev:agent-core`, 권한이 `750`으로 설정된 것을 확인한 화면입니다. `/etc/profile.d/agent-app.sh` 환경 변수 설정도 확인했습니다.

### 4. monitor.sh 설치

![monitor.sh 설치 확인](chapter/4.monitor_install.png)

`monitor.sh`를 `/home/agent-admin/agent-app/bin/monitor.sh`에 설치하고, 소유자/그룹을 `agent-dev:agent-core`, 권한을 `750`으로 설정한 것을 확인한 화면입니다.

### 5. UFW 방화벽 설정

![방화벽 설정 확인](chapter/5.firewall.png)

UFW를 활성화하고 incoming 기본 정책을 deny, outgoing 기본 정책을 allow로 설정한 화면입니다. SSH 포트 `20022/tcp`와 Agent 포트 `15034/tcp`가 IPv4/IPv6 모두에서 허용된 것을 확인했습니다.

### 6. Agent 앱 실행

![Agent 실행 확인](chapter/6.agent_run.png)

`agent-admin` 계정으로 Agent 앱을 실행한 화면입니다. Boot Sequence 5단계가 모두 `[OK]`로 통과했고, `Agent READY` 및 `Agent listening at port 15034` 상태를 확인했습니다.

### 7. Agent 프로세스 및 포트 확인

![Agent 포트 확인](chapter/7.agent_port.png)

`ss -tulnp | grep 15034`와 `pgrep -af agent-app`로 Agent 앱이 `0.0.0.0:15034`에서 LISTEN 중이며 프로세스가 실행 중인 것을 확인한 화면입니다.

### 8. monitor.sh 수동 실행 및 로그 확인

![monitor.sh 수동 실행](chapter/8.monitor_manual.png)

`monitor.sh`를 수동 실행해 프로세스, 포트, 방화벽 상태가 `[OK]`인 것을 확인한 화면입니다. CPU/MEM/DISK 사용량이 출력되고 `/var/log/agent-app/monitor.log`에 로그가 누적 기록된 것도 확인했습니다.

### 9. cron 등록 및 자동 실행 확인

![cron 등록 및 자동 실행 확인](chapter/9.cron.png)

`agent-admin` 계정의 crontab에 `monitor.sh` 매분 실행 항목을 등록하고, 70초 뒤 `monitor.log`에 새 로그가 추가된 것을 확인한 화면입니다.

### 10. 전체 검증

![전체 검증](chapter/10.verify_all.png)

`verify_all.sh`로 방화벽, 계정/그룹, 디렉터리/파일 권한, Agent 프로세스, `15034` 포트, monitor 로그, cron 등록 상태를 한 번에 확인한 화면입니다.

### 11. SSH 보안 설정

![SSH 설정 확인](chapter/11.ssh.png)

`sshd -T`로 SSH 포트가 `20022`이고 `PermitRootLogin`이 `no`로 설정된 것을 확인한 화면입니다.
