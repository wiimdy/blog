---
title: "FSOP_BASIC"
# subtitle: "File struct basic knowledge"
date: 2024-08-19 15:13:09 +0900

description: "This post explains what is the file strut pointer and file vtables."
authors: wiimdy
tags: [pwn, FSOP]
categories: [PWN_DOCS]
---

<!-- This post explains what is the file strut pointer and file vtables.
more -->

## FILE 포인터란?

리눅스에서 "파일 포인터"는 프로그램이 파일을 읽거나 쓸 때 그 파일의 현재 위치를 추적하는 데 사용되는 개념입니다. 파일 포인터는 파일 내에서의 현재 위치를 가리키며, 이 위치는 파일 내에서 데이터를 읽거나 쓸 때마다 변경됩니다.

### 파일 포인터의 주요 특징:

1.  **파일 내 위치 추적**:
    - 파일 포인터는 파일 내의 특정 위치를 가리킵니다. 예를 들어, 파일의 처음, 중간 또는 끝을 가리킬 수 있습니다.
    - 파일을 읽거나 쓰는 작업을 수행할 때, 파일 포인터는 자동으로 이동하여 다음 읽기 또는 쓰기 작업이 어디에서 시작될지를 결정합니다.
2.  **파일 입출력 함수와 연관**:
    - C 언어나 다른 프로그래밍 언어에서 파일을 처리할 때 사용하는 함수(`fopen`, `fread`, `fwrite`, `fseek`, `fclose` 등)는 파일 포인터를 사용합니다.
    - 예를 들어, `fseek` 함수는 파일 포인터를 파일의 특정 위치로 이동시키는 데 사용됩니다.
3.  **파일 디스크립터와의 관계**:
    - 파일 포인터는 보통 고수준 입출력에서 사용되며, 이와 대조적으로 저수준 입출력에서는 파일 디스크립터(file descriptor)가 사용됩니다. 파일 디스크립터는 리눅스 커널에서 파일을 식별하는 정수 값입니다.
    - 파일 디스크립터가 커널 수준에서 파일을 관리하는 반면, 파일 포인터는 사용자 공간에서 파일의 위치를 추적합니다.

## FILE 구조체

### _IO_FILE_PLUS_

```c
struct _IO_FILE_plus
{
  FILE file;
  const struct _IO_jump_t *vtable;
};
```

- 이 구조체 안에 FILE이라는 구조체가 있고 FILE에서 참조하는 jump_t 라는 vtable(함수 테이블)이 있다.

### \_IO_FILE

```c
struct _IO_FILE
{
  int _flags;       /* High-order word is _IO_MAGIC; rest is flags. */
  /* The following pointers correspond to the C++ streambuf protocol. */
  char *_IO_read_ptr;   /* Current read pointer */
  char *_IO_read_end;   /* End of get area. */
  char *_IO_read_base;  /* Start of putback+get area. */
  char *_IO_write_base; /* Start of put area. */
  char *_IO_write_ptr;  /* Current put pointer. */
  char *_IO_write_end;  /* End of put area. */
  char *_IO_buf_base;   /* Start of reserve area. */
  char *_IO_buf_end;    /* End of reserve area. */
  /* The following fields are used to support backing up and undo. */
  char *_IO_save_base; /* Pointer to start of non-current get area. */
  char *_IO_backup_base;  /* Pointer to first valid character of backup area */
  char *_IO_save_end; /* Pointer to end of non-current get area. */
  struct _IO_marker *_markers;
  struct _IO_FILE *_chain;
  int _fileno;
  int _flags2;
  __off_t _old_offset; /* This used to be _offset but it's too small.  */
  /* 1+column number of pbase(); 0 is unknown. */
  unsigned short _cur_column;
  signed char _vtable_offset;
  char _shortbuf[1];
  _IO_lock_t *_lock;
#ifdef _IO_USE_OLD_IO_FILE
};
```

다음은 stdout에 있는 값들이다
![Desktop View](/assets/img/pwn/dbd3945c06edd75953a7bac4676f41716409f139.png)

차례대로 flag, **IO_FILE \*\*chain** , vtable 이다.

- flags: 파일에 대한 읽기/쓰기/추가 권한을 의미한다. `0xfbad0000` 값을 매직 값으로, 하위 2바이트는 비트 플래그로 사용된다.
- chain : IO_FILE 구조체는 chain 필드를 통해 링크드 리스트로 이루어져있다. 링크드 리스트의 헤더는 라이브러리의 전역 변수인 IO_list_all에 저장된다.
- vtable: 파일 관련 작업을 수행하는 가상 함수 테이블이다.

### IO_FILE: FLAG

---

```java
#define _IO_MAGIC         0xFBAD0000 /* Magic number */
#define _IO_MAGIC_MASK    0xFFFF0000
#define _IO_USER_BUF          0x0001 /* Don't deallocate buffer on close. */
#define _IO_UNBUFFERED        0x0002
#define _IO_NO_READS          0x0004 /* Reading not allowed.  */
#define _IO_NO_WRITES         0x0008 /* Writing not allowed.  */
#define _IO_EOF_SEEN          0x0010
#define _IO_ERR_SEEN          0x0020
#define _IO_DELETE_DONT_CLOSE 0x0040 /* Don't call close(_fileno) on close.  */
#define _IO_LINKED            0x0080 /* In the list of all open files.  */
#define _IO_IN_BACKUP         0x0100
#define _IO_LINE_BUF          0x0200
#define _IO_TIED_PUT_GET      0x0400 /* Put and get pointer move in unison.  */
#define _IO_CURRENTLY_PUTTING 0x0800
#define _IO_IS_APPENDING      0x1000
#define _IO_IS_FILEBUF        0x2000 /* 0x4000  No longer used, reserved for compat.  */
#define _IO_USER_LOCK         0x8000
```

flag가 `0xfbad2887` 이므로 `_IO_IS_FILEBUF, _IO_CURRENTLY_PUTTING, _IO_LINKED, _IO_NO_READS , _IO_UNBUFFERED, _IO_USER_BUF_` 가 있다.

즉 stdout은 출력 스트림에 쓰는 파일 포인터이기 때문에 NO_READS이고 CURRENTLY_PUTTING 상태이다. stdout, stdin, stderr는 연결되어 있기 때문에 linked가 설정되어 있다.

#### IO_FILE: vtable

vtable은 객체 지향 프로그래밍 언어에서 클래스를 정의하고 가상 함수를 사용할 때 할당되는 테이블이다. 메모리에 가상 함수를 담을 영역을 할당하고, 주소를 기록한다. 가상 함수를 사용할 때 테이블을 기준으로 offset을 통해 호출한다.

파일 함수의 테이블은 `_IO_jump_t` 구조체에 구성되어 있다

#### IO_jump_t

```c
struct _IO_jump_t
{
    JUMP_FIELD(size_t, __dummy);
    JUMP_FIELD(size_t, __dummy2);
    JUMP_FIELD(_IO_finish_t, __finish);
    JUMP_FIELD(_IO_overflow_t, __overflow);
    JUMP_FIELD(_IO_underflow_t, __underflow);
    JUMP_FIELD(_IO_underflow_t, __uflow);
    JUMP_FIELD(_IO_pbackfail_t, __pbackfail);
    /* showmany */
    JUMP_FIELD(_IO_xsputn_t, __xsputn);
    JUMP_FIELD(_IO_xsgetn_t, __xsgetn);
    JUMP_FIELD(_IO_seekoff_t, __seekoff);
    JUMP_FIELD(_IO_seekpos_t, __seekpos);
    JUMP_FIELD(_IO_setbuf_t, __setbuf);
    JUMP_FIELD(_IO_sync_t, __sync);
    JUMP_FIELD(_IO_doallocate_t, __doallocate);
    JUMP_FIELD(_IO_read_t, __read);
    JUMP_FIELD(_IO_write_t, __write);
    JUMP_FIELD(_IO_seek_t, __seek);
    JUMP_FIELD(_IO_close_t, __close);
    JUMP_FIELD(_IO_stat_t, __stat);
    JUMP_FIELD(_IO_showmanyc_t, __showmanyc);
    JUMP_FIELD(_IO_imbue_t, __imbue);
};
```

![file_vtable.png](/assets/img/pwn/a46faed61e37dab6ba791d577237faa4f00b5d12.png)
실제로 구현되어 있는 file_vtable의 모습이다

그럼 이 vtable이 어떻게 사용되는지 알아 보자.

puts 함수의 구조이다.

```c
#include "libioP.h"
#include <string.h>
#include <limits.h>
int
_IO_puts (const char *str)
{
  int result = EOF;
  size_t len = strlen (str);
  _IO_acquire_lock (stdout);
  if ((_IO_vtable_offset (stdout) != 0
       || _IO_fwide (stdout, -1) == -1)
      && _IO_sputn (stdout, str, len) == len
      && _IO_putc_unlocked ('n', stdout) != EOF)
    result = MIN (INT_MAX, len + 1);
  _IO_release_lock (stdout);
  return result;
}
weak_alias (_IO_puts, puts)
libc_hidden_def (_IO_puts)
```

`_IO_sputn` 이라는 함수를 실행하여 문자열을 출력한다.

우리는 vtable 에 `_IO_xsputn` 을 가지고 있지만 이 주소를 변경할 수 는 없다.

```c
static inline const struct _IO_jump_t *
IO_validate_vtable (const struct _IO_jump_t *vtable)
{
  /* Fast path: The vtable pointer is within the __libc_IO_vtables
     section.  */
  uintptr_t section_length = __stop___libc_IO_vtables - __start___libc_IO_vtables;
  uintptr_t ptr = (uintptr_t) vtable;
  uintptr_t offset = ptr - (uintptr_t) __start___libc_IO_vtables;
  if (__glibc_unlikely (offset >= section_length))
    /* The vtable pointer is not in the expected section.  Use the
       slow path, which will terminate the process if necessary.  */
    _IO_vtable_check ();
  return vtable;
}
```

`IO_validate_vtable` 이라는 함수를 통해 vtable 에 있는 값들이 `_libc_IO_vtable` 안에 있는지 검사를 진행한다.
즉 우리가 원하는 아무 함수나 덮을순 없다.

다른 방법으로 `_libc_IO_vtables` 구역에 있는 함수 중 취약한 함수들을 찾는 것이다.
`_IO_file_vtables` 이외에 `_IO_str_jumps table`, `_IO_wfile_jumps table` 이 있다

#### IO_wide_data

```c
/* Extra data for wide character streams.  */
struct _IO_wide_data
{
  wchar_t *_IO_read_ptr;
  wchar_t *_IO_read_end;
  wchar_t *_IO_read_base;
  wchar_t *_IO_write_base; // 0x18
  wchar_t *_IO_write_ptr;
  wchar_t *_IO_write_end;
  wchar_t *_IO_buf_base; // 0x30
  wchar_t *_IO_buf_end;
  wchar_t *_IO_save_base;
  wchar_t *_IO_backup_base;
  wchar_t *_IO_save_end;
  __mbstate_t _IO_state;
  __mbstate_t _IO_last_state;
  struct _IO_codecvt _codecvt;
  wchar_t _shortbuf[1];
  const struct _IO_jump_t *_wide_vtable; // 0xe0
};

const struct _IO_jump_t _IO_wfile_jumps libio_vtable =
{
  JUMP_INIT_DUMMY,
  JUMP_INIT(finish, _IO_new_file_finish),
  JUMP_INIT(overflow, (_IO_overflow_t) _IO_wfile_overflow),
  JUMP_INIT(underflow, (_IO_underflow_t) _IO_wfile_underflow),
  JUMP_INIT(uflow, (_IO_underflow_t) _IO_wdefault_uflow),
  JUMP_INIT(pbackfail, (_IO_pbackfail_t) _IO_wdefault_pbackfail),
  JUMP_INIT(xsputn, _IO_wfile_xsputn),
  JUMP_INIT(xsgetn, _IO_file_xsgetn),
  JUMP_INIT(seekoff, _IO_wfile_seekoff),
  JUMP_INIT(seekpos, _IO_default_seekpos),
  JUMP_INIT(setbuf, _IO_new_file_setbuf),
  JUMP_INIT(sync, (_IO_sync_t) _IO_wfile_sync),
  JUMP_INIT(doallocate, _IO_wfile_doallocate),
  JUMP_INIT(read, _IO_file_read),
  JUMP_INIT(write, _IO_new_file_write),
  JUMP_INIT(seek, _IO_file_seek),
  JUMP_INIT(close, _IO_file_close),
  JUMP_INIT(stat, _IO_file_stat),
  JUMP_INIT(showmanyc, _IO_default_showmanyc),
  JUMP_INIT(imbue, _IO_default_imbue)
};
```

## Exit_routine IO_cleanup overwite

주로 이 exploit을 사용하는 경우 중 하나는 glibc 2.34 이후 malloc_hook. free_hook등 이 사라지면서 shell을 얻을 overwite 할 곳이 없을 때 진행된다.

`_IO_wfile_jumps` 에 있는 vtable를 참조하여 함수를 호출 할 때 `IO_validate_vtable` 을 검사하지 않아 원하는 함수를 덮을 수 있다.

### 1. exit 함수 실행될 때

- exit 함수가 실행 될 때 : exit -> fcloseall -> `_IO_cleanup` -> `_IO_flush_all_lockp` 가 실행된다.

```c
int _IO_flush_all_lockp (int do_lock)
{
  int result = 0;
  FILE *fp;

#ifdef _IO_MTSAFE_IO
  _IO_cleanup_region_start_noarg (flush_cleanup);
  _IO_lock_lock (list_all_lock);
#endif

  for (fp = (FILE *) _IO_list_all; fp != NULL; fp = fp->_chain)
    {
      run_fp = fp;
      if (do_lock)
    _IO_flockfile (fp);

      if (((fp->_mode <= 0 && fp->_IO_write_ptr > fp->_IO_write_base)
       || (_IO_vtable_offset (fp) == 0
           && fp->_mode > 0 && (fp->_wide_data->_IO_write_ptr
                    > fp->_wide_data->_IO_write_base))
       )
      && _IO_OVERFLOW (fp, EOF) == EOF) // <--- overflow call
    result = EOF;

      if (do_lock)
    _IO_funlockfile (fp);
      run_fp = NULL;
    }

#ifdef _IO_MTSAFE_IO
  _IO_lock_unlock (list_all_lock);
  _IO_cleanup_region_end (0);
#endif

  return result;
}

// definition of _IO_OVERFLOW
typedef int (*_IO_overflow_t) (FILE *, int);
#define _IO_OVERFLOW(FP, CH) JUMP1 (__overflow, FP, CH)
#define _IO_WOVERFLOW(FP, CH) WJUMP1 (__overflow, FP, CH)
```

참고 사이트
<https://samuzora.com/posts/fsop/house-of-apple/>

<https://blog.kylebot.net/2022/10/22/angry-FSROP/>

<https://github.com/nobodyisnobody/docs/blob/main/code.execution.on.last.libc/README.md>
