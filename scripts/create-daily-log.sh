#!/bin/bash

# TIL 일일 로그 자동 생성 스크립트
# 사용법: ./create-daily-log.sh [YYYY-MM-DD]
# 날짜를 지정하지 않으면 오늘 날짜로 생성

set -e  # 에러 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 기본 설정
TEMPLATE_FILE="templates/daily-template.md"
DAILY_LOGS_DIR="daily-logs"

# OS 감지
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
else
    IS_MACOS=false
fi

# 함수: 에러 메시지 출력
error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
    exit 1
}

# 함수: 성공 메시지 출력
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 함수: 정보 메시지 출력
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 함수: 경고 메시지 출력
warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 함수: 날짜 유효성 검사 (macOS/Linux 호환)
validate_date() {
    local date_input="$1"
    
    # YYYY-MM-DD 형식 검사
    if [[ ! $date_input =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        error "Invalid date format: $date_input. Please use YYYY-MM-DD format."
    fi
    
    # 날짜 유효성 검사
    local year=$(echo "$date_input" | cut -d'-' -f1)
    local month=$(echo "$date_input" | cut -d'-' -f2)
    local day=$(echo "$date_input" | cut -d'-' -f3)
    
    # 기본적인 범위 체크
    if [ "$year" -lt 1900 ] || [ "$year" -gt 2100 ]; then
        error "Year must be between 1900 and 2100"
    fi
    
    if [ "$month" -lt 1 ] || [ "$month" -gt 12 ]; then
        error "Month must be between 01 and 12"
    fi
    
    if [ "$day" -lt 1 ] || [ "$day" -gt 31 ]; then
        error "Day must be between 01 and 31"
    fi
    
    # 실제 날짜 유효성 검사
    if $IS_MACOS; then
        if ! date -j -f "%Y-%m-%d" "$date_input" "+%Y-%m-%d" >/dev/null 2>&1; then
            error "Invalid date: $date_input"
        fi
    else
        if ! date -d "$date_input" >/dev/null 2>&1; then
            error "Invalid date: $date_input"
        fi
    fi
}

# 함수: 날짜에서 년/월/일 추출
extract_date_parts() {
    local target_date="$1"
    
    if $IS_MACOS; then
        YEAR=$(date -j -f "%Y-%m-%d" "$target_date" "+%Y")
        MONTH=$(date -j -f "%Y-%m-%d" "$target_date" "+%m") 
        DAY=$(date -j -f "%Y-%m-%d" "$target_date" "+%d")
        FORMATTED_DATE=$(date -j -f "%Y-%m-%d" "$target_date" "+%Y-%m-%d")
        KOREAN_DATE=$(date -j -f "%Y-%m-%d" "$target_date" "+%Y년 %m월 %d일")
        DAY_OF_WEEK=$(date -j -f "%Y-%m-%d" "$target_date" "+%A")
    else
        YEAR=$(date -d "$target_date" +%Y)
        MONTH=$(date -d "$target_date" +%m)
        DAY=$(date -d "$target_date" +%d)
        FORMATTED_DATE=$(date -d "$target_date" +%Y-%m-%d)
        KOREAN_DATE=$(date -d "$target_date" +%Y년\ %m월\ %d일)
        DAY_OF_WEEK=$(date -d "$target_date" +%A)
    fi
    
    # 요일을 한국어로 변환
    case $DAY_OF_WEEK in
        "Monday") DAY_OF_WEEK="월요일" ;;
        "Tuesday") DAY_OF_WEEK="화요일" ;;
        "Wednesday") DAY_OF_WEEK="수요일" ;;
        "Thursday") DAY_OF_WEEK="목요일" ;;
        "Friday") DAY_OF_WEEK="금요일" ;;
        "Saturday") DAY_OF_WEEK="토요일" ;;
        "Sunday") DAY_OF_WEEK="일요일" ;;
    esac
}

# 함수: 오늘 날짜 가져오기
get_today() {
    if $IS_MACOS; then
        date "+%Y-%m-%d"
    else
        date +%Y-%m-%d
    fi
}

# 함수: 디렉토리 생성
create_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        info "Created directory: $dir"
    fi
}

# 함수: 템플릿 파일 존재 확인
check_template() {
    if [ ! -f "$TEMPLATE_FILE" ]; then
        error "Template file not found: $TEMPLATE_FILE"
    fi
}

# 함수: 일일 로그 파일 생성
create_daily_log() {
    local target_date="$1"
    
    # 날짜 정보 추출
    extract_date_parts "$target_date"
    
    # 디렉토리 구조 생성
    local target_dir="$DAILY_LOGS_DIR/$YEAR/$MONTH"
    create_directory "$target_dir"
    
    # 파일 경로
    local target_file="$target_dir/$FORMATTED_DATE.md"
    
    # 파일이 이미 존재하는지 확인
    if [ -f "$target_file" ]; then
        warning "File already exists: $target_file"
        echo -n "Do you want to overwrite it? (y/N): "
        read -r REPLY
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Operation cancelled."
            exit 0
        fi
    fi
    
    # 템플릿 복사 및 날짜 치환
    if command -v sed >/dev/null 2>&1; then
        sed -e "s/YYYY-MM-DD/$FORMATTED_DATE/g" \
            -e "s/YYYY년 MM월 DD일/$KOREAN_DATE/g" \
            -e "s/요일/$DAY_OF_WEEK/g" \
            "$TEMPLATE_FILE" > "$target_file"
    else
        # sed가 없는 경우 기본 복사
        cp "$TEMPLATE_FILE" "$target_file"
        warning "sed not found. Template copied without date substitution."
    fi
    
    success "Created daily log: $target_file"
    info "Korean date: $KOREAN_DATE ($DAY_OF_WEEK)"
    
    # 파일 열기 여부 확인
    echo -n "Do you want to open the file? (y/N): "
    read -r REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 기본 에디터로 파일 열기
        if command -v code >/dev/null 2>&1; then
            code "$target_file"
        elif command -v vim >/dev/null 2>&1; then
            vim "$target_file"
        elif command -v nano >/dev/null 2>&1; then
            nano "$target_file"
        elif command -v open >/dev/null 2>&1; then
            # macOS의 경우
            open "$target_file"
        else
            info "Please open the file manually: $target_file"
        fi
    fi
}

# 메인 로직
main() {
    echo -e "${BLUE}🚀 TIL Daily Log Generator${NC}"
    echo "=================================="
    info "OS detected: $(if $IS_MACOS; then echo "macOS"; else echo "Linux"; fi)"
    
    # 템플릿 파일 확인
    check_template
    
    # 날짜 처리
    local target_date
    if [ $# -eq 0 ]; then
        # 인자가 없으면 오늘 날짜 사용
        target_date=$(get_today)
        info "No date specified. Using today: $target_date"
    elif [ $# -eq 1 ]; then
        # 날짜가 지정된 경우
        target_date="$1"
        validate_date "$target_date"
        info "Using specified date: $target_date"
    else
        error "Too many arguments. Usage: $0 [YYYY-MM-DD]"
    fi
    
    # 일일 로그 생성
    create_daily_log "$target_date"
}

# 도움말 표시
show_help() {
    echo "TIL Daily Log Generator"
    echo ""
    echo "Usage:"
    echo "  $0                    # Create log for today"
    echo "  $0 YYYY-MM-DD         # Create log for specific date"
    echo "  $0 -h, --help         # Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                    # Creates log for today"
    echo "  $0 2025-06-10         # Creates log for June 10, 2025"
    echo "  $0 2025-12-25         # Creates log for December 25, 2025"
    echo ""
    echo "Requirements:"
    echo "  - Template file must exist at: $TEMPLATE_FILE"
    echo "  - Daily logs will be created in: $DAILY_LOGS_DIR/YYYY/MM/"
    echo ""
    echo "Compatibility:"
    echo "  - macOS (BSD date): ✅"
    echo "  - Linux (GNU date): ✅"
    echo "  - bash 3.2+: ✅"
}

# 인자 처리
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac