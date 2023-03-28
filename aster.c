#include "aster.h"
#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

char aster_dict[ASTER_DICTSZ];
int aster_stack[ASTER_STACKSZ];
int aster_rstack[ASTER_RSTACKSZ];
int aster_sp=0, aster_rsp=0, aster_pc=0;
int aster_here=ASTER_DICTSTART, aster_old=ASTER_DICTSTART;
int aster_stringPtr=ASTER_STRINGSTART;
struct aster_word aster_words[ASTER_WORDSSZ];
int aster_nwords=0;
char (*aster_nextChar)(void) = 0;
char *aster_string;
FILE *aster_fp;
int aster_status = ASTER_RUN;
char aster_nameBuf[ASTER_NAMEBUFSZ];
char *aster_nextName = aster_nameBuf;

void aster_addC(void (*fun)(void), const char *name, int flag)
{
    aster_words[aster_nwords++] = (struct aster_word)
    {
        name,
        flag|ASTER_C, 0, 0,
        fun,
    };
}

struct aster_word *aster_findWord(const char *name)
{
    int i;
    for(i = aster_nwords-1; i >= 0; i--)
        if(!strcmp(name, aster_words[i].name))
            return &aster_words[i];
    return 0;
}

struct aster_word *aster_findC(void (*fun)(void))
{
    int i;
    for(i = aster_nwords-1; i >= 0; i--)
        if(aster_words[i].fun == fun)
            return &aster_words[i];
    return 0;
}

void aster_run()
{
    void (*fun)(void);
    while(fun = *(void (**)(void))(aster_dict+aster_pc))
    {
        /*printf(":%X\n", aster_pc);*/
        aster_pc += sizeof(void (*)(void));
        fun();
    }
}

int aster_num(char *s, int *n)
{
    int i;
    int base;
    int f = 0;
    if(*s == '-') { f = 1; s++; }
    if(*s == 0) return 0;
    base = *(int*)(aster_dict+ASTER_BASE);
    *n = 0;
    do {
        if(base <= 10) {
            if(*s >= '0' && *s < '0'+base)
                *n = *n * base + *s - '0';
            else return 0;
        } else {
            if(*s >= '0' && *s <= '9')
                *n = *n * base + *s - '0';
            else if(*s >= 'A' && *s < 'A'+base-10)
                *n = *n * base + *s - 'A' + 10;
            else return 0;
        }
    } while(*(++s));
    if(f) *n *= -1;
    return 1;
}

void aster_doToken(char *s)
{
    struct aster_word *w;
    int n;
    w = aster_findWord(s);
    if(w) {
        if(w->flag & ASTER_IMMEDIATE) {
            if(w->flag & ASTER_C) w->fun();
            else { aster_pc = w->addr; aster_run(); }
        } else if(w->flag & ASTER_C) {
            *(void (**)(void))(aster_dict+aster_here) = w->fun;
            aster_here += sizeof(void (*)(void))/sizeof(char);
        } else {
            *(void (**)(void))(aster_dict+aster_here) = aster_call;
            aster_here += sizeof(void (*)(void))/sizeof(char);
            *(int*)(aster_dict+aster_here) = w->addr;
            aster_here += sizeof(int)/sizeof(char);
        }
    } else if(aster_num(s, &n)) {
        *(void (**)(void))(aster_dict+aster_here) = aster_push;
        aster_here += sizeof(void (*)(void))/sizeof(char);
        *(int*)(aster_dict+aster_here) = n;
        aster_here += sizeof(int)/sizeof(char);
    } else { printf("%s ?\n", s); exit(1); }
}

void aster_print(int addr, int addr2)
{
    void (*fun)(void);
    struct aster_word *w;
    while(addr < addr2)
    {
        fun = *(void (**)(void))(aster_dict+addr);
        printf("%.8X ", addr);
        addr += sizeof(void (*)(void));
        if(fun == aster_jmp) {
            printf("jmp 0x%x", *(int*)(aster_dict+addr));
            addr += sizeof(int)/sizeof(char);
        } else if(fun == aster_jz) {
            printf("jz 0x%x", *(int*)(aster_dict+addr));
            addr += sizeof(int)/sizeof(char);
        } else if(fun == aster_call) {
            printf("call 0x%x", *(int*)(aster_dict+addr));
            addr += sizeof(int)/sizeof(char);
        } else if(fun == aster_push) {
            printf("push %d", *(int*)(aster_dict+addr));
            addr += sizeof(int)/sizeof(char);
        } else if(fun == aster_ret) {
            printf("ret");
        } else if(w = aster_findC(fun)) printf("%s", w->name);
        else printf("0x%x", (unsigned)(size_t)fun);
        printf("\n");
    }
}

void aster_runAll()
{
    char buf[512];
    char *s;
    s = buf;
    char c;
    for(;;)
    {
        *s = aster_nextChar();
        if(*s <= ' ') {
            c = *s;
            if(s != buf) {
                *s = 0;
                aster_doToken(buf);
                s = buf;
            }
            if(/*(c == 0 || c == '\n') &&*/ aster_status != ASTER_WORD
                    && aster_old != aster_here && !aster_rsp) {
                *(void (**)(void))(aster_dict+aster_here) = 0;
                aster_pc = aster_old;
                aster_run();
                aster_here = aster_old;
            }
            if(c == 0) return;
        } else {
            if(*s >= 'a' && *s <= 'z') *s += 'A'-'a';
            s++;
        }
    }
}

char aster_nextChar_string()
{
    if(!(*aster_string)) return 0;
    return *(aster_string++);
}

void aster_runString(char *s)
{
    char (*old_nextChar)(void);
    char *old_string;
    old_nextChar = aster_nextChar;
    old_string = aster_string;
    aster_nextChar = aster_nextChar_string;
    aster_string = s;
    aster_runAll();
    aster_string = old_string;
    aster_nextChar = old_nextChar;
}

char aster_nextChar_file()
{
    if(feof(aster_fp)) return 0;
    return fgetc(aster_fp);
}

void aster_runFile(const char *filename)
{
    char (*old_nextChar)(void);
    FILE *old_fp;
    old_nextChar = aster_nextChar;
    old_fp = aster_fp;
    aster_fp = fopen(filename, "r");
    if(!aster_fp) { printf("failed to open %s\n", filename); exit(1); }
    aster_nextChar = aster_nextChar_file;
    aster_runAll();
    aster_fp = old_fp;
    aster_nextChar = old_nextChar;
}

void aster_runPrompt()
{
    char buf[512];
    char *s;
    char c;
    for(;;)
    {
        if(aster_old == aster_here) printf("  ok\n");
        else printf("  compiled\n");
        s = buf;
        do {
            c = fgetc(stdin);
            *(s++) = c;
        } while(c >= ' ' || c == '\t');
        *(s-1) = 0;
        aster_runString(buf);
    }
}

