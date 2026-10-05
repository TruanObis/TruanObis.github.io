# 글 관리 안내

공개 블로그: https://truanobis.github.io/

글 관리: https://app.pagescms.org/truanobis/truanobis.github.io/main/collection/posts

블로그 이름과 작성자 이름은 비워 두었습니다. 첫 글은 직접 등록해 주세요.

## 최초 연결

1. Pages CMS에서 **Sign in with GitHub**로 로그인합니다.
2. GitHub 앱 설치가 표시되면 **Only select repositories**를 선택하고 `TruanObis.github.io`만 연결합니다.
3. 저장소 `TruanObis.github.io`, 브랜치 `main`을 엽니다. `.pages.yml`에 정의한 편집 화면이 표시됩니다.

## 글 등록·수정·삭제

- **등록:** 왼쪽 **글** → 새 글 → 제목·본문 입력 → 저장. 작성일과 고유 주소는 자동으로 준비됩니다.
- **수정:** 글을 선택하고 수정한 뒤 저장합니다. 제목을 바꿔도 주소는 유지됩니다. 수정일은 Git 커밋에서 자동 계산합니다.
- **삭제:** 글을 선택하고 삭제합니다. 다음 배포에서 웹페이지·Markdown·피드·사이트맵에서 빠집니다.
- **게시 중지:** **사이트에 게시**를 끄고 저장합니다. 사이트에서는 제외되지만 공개 저장소의 파일·이력은 공개됩니다. 비밀 초안은 로컬에 보관하세요.
- **이미지:** 본문 편집기의 이미지 도구로 올립니다. 파일은 `assets/uploads`에 저장됩니다.
- **설정:** **블로그 설정**에서 이름·작성자·소개를 수정할 수 있습니다. 이름과 작성자를 비우면 화면에 표시하지 않습니다.

저장 후 [Actions](https://github.com/TruanObis/TruanObis.github.io/actions)에서 `Verify and publish blog` 실행이 성공하면 사이트에 반영됩니다. 새 글의 날짜를 미래로 지정하면 제외되며, 예약 시간에 자동 배포하는 기능은 없습니다. 당일 이후 저장하거나 워크플로를 수동 실행해야 표시됩니다.

## AI 접근성

- 본문 전체가 정적 HTML에 포함됩니다. 로그인과 JavaScript 실행이 필요하지 않습니다.
- 각 글에 `/posts/고유ID/index.md` 원문이 있습니다.
- `/posts.json`, `/llms.txt`, `/feed.xml`, `/sitemap.xml`이 자동 생성됩니다.
- `/robots.txt`는 모든 크롤러의 접근을 허용합니다.
- 콘텐츠 이용 범위는 [이용 안내](https://truanobis.github.io/policy/)에 명시합니다. CC BY 등 일반 재배포 라이선스는 별도로 부여하지 않았습니다.

## 직접 파일을 편집할 때

글은 `_posts/YYYY-MM-DD-고유ID.md`이며 `uid`는 UUID v4입니다. `uid`를 바꾸거나 중복시키지 마세요. `title`, `date`, `published`, `description`, `tags`와 본문을 편집할 수 있습니다. 템플릿 표현식은 본문에서 실행하지 않습니다.

## 개발과 검증

Ruby 3.3 환경에서:

```sh
bundle install
bundle exec ruby test/site_test.rb
bundle exec jekyll serve
```

실제 Jekyll 빌드로 원문·HTML·JSON·XML, 한국어와 특수문자, 제목 변경 시 주소 유지, 숨김·미래 글 제외, 삭제 반영, Git 수정일, 고유ID 충돌을 검증합니다. Actions는 테스트 실패 시 배포하지 않습니다.

GitHub Pages의 Build and deployment / Source는 **GitHub Actions**로 유지하세요. 사용자 정의 원문 생성 플러그인은 브랜치 직접 배포 모드에서 실행되지 않습니다.
