# To learn more about how to use Nix to configure your environment
# see: https://firebase.google.com/docs/studio/customize-workspace
{ pkgs, ... }: {
  # Which nixpkgs channel to use.
  channel = "stable-24.05"; # or "unstable"

  # 필요한 도구를 여기에 추가하여 영구적으로 사용합니다
  packages = [
    pkgs.jdk21
    pkgs.unzip
    pkgs.psmisc   # killall, fuser 명령어를 제공합니다
    pkgs.busybox  # 리눅스 기본 명령어 모음집입니다
  ];

  # Sets environment variables in the workspace
  env = {};

  idx = {
    # Search for the extensions you want on https://open-vsx.org/ and use "publisher.id"
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];

    workspace = {
      # 워크스테이션 시작 시 실행할 작업을 정의합니다
      onCreate = { };
      
      # 시작할 때마다 유령 프로세스를 자동으로 정리하여 포트 충돌을 방지합니다
      onStart = {
        kill-ghost-dart = "pkill -9 dart || true";
      };
    };

    # 미리보기 설정 최적화
    previews = {
      enable = true;
      previews = {
        web = {
          # 포트 충돌 방지를 위해 시스템 할당 포트($PORT)를 사용하도록 고정합니다
          command = ["flutter" "run" "--machine" "-d" "web-server" "--web-hostname" "0.0.0.0" "--web-port" "$PORT"];
          manager = "flutter";
        };
        android = {
          # 기기 중복 인식을 막기 위해 고유 ID로 명시적 연결을 시도합니다
          command = ["flutter" "run" "--machine" "-d" "emulator-5554"];
          manager = "flutter";
        };
      };
    };
  };
}