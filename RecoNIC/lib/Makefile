# 
# Makefile
# -- The script is used to generate library files: libreconic.so and libreconic.a
# -- 这个脚本用于生成库文件: libreconic.so 和 libreconic.a
#
# ==============================================================================

# =========================
#  1. 编译与链接器设置
# =========================
# C编译器使用gcc
CC = gcc
# 编译标志：
# -Wall: 开启所有常用警告
# -Werror: 将所有警告视为错误，强制保证代码质量
# -fPIC: 生成位置无关代码 (Position-Independent Code)，这是编译共享库所必需的
CFLAGS = -Wall -Werror -fPIC

# =========================
#  2. 目录与文件变量定义
# =========================
# 定义源码、目标文件和库文件所在的目录
# $(CURDIR) 是一个Makefile内置变量，代表当前目录
SRC_DIR = $(CURDIR)
OBJ_DIR = $(CURDIR)/obj
LIB_DIR = $(CURDIR)

# 自动查找所有.c源文件
# $(wildcard ...): 这是一个函数，用于查找匹配模式的所有文件
SRCS = $(wildcard $(SRC_DIR)/*.c)
# 根据找到的.c文件列表，生成对应的.o目标文件列表
# $(patsubst ...): 这是一个模式替换函数，它将$(SRCS)中所有以.c结尾的路径
#                 替换为以.o结尾且存放在$(OBJ_DIR)目录下的路径。
# 例如：./main.c -> ./obj/main.o
OBJS = $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR)/%.o,$(SRCS))

# 定义最终输出的库文件名
LIB_NAME = libreconic
# 定义完整的共享库文件路径
SHARED_LIB = $(LIB_DIR)/$(LIB_NAME).so
# 定义完整的静态库文件路径
STATIC_LIB = $(LIB_DIR)/$(LIB_NAME).a

# =========================
#  3. 目标与规则定义
# =========================
# "all" 是一个总目标，也是默认目标（因为它是第一个）
# 当执行 "make" 或 "make all" 时，它会尝试构建它的依赖项：共享库和静态库
all: $(SHARED_LIB) $(STATIC_LIB)

# --- 规则：如何生成共享库 ---
# 目标：$(SHARED_LIB) (即 libreconic.so)
# 依赖：$(OBJS) (所有的 .o 目标文件)
# 命令：当所有.o文件都准备好后，执行此命令来链接它们
#  $(CC): 使用gcc
#  -shared: 告诉链接器要生成一个共享库
#  -o $@: 指定输出文件名。"$@" 是一个自动化变量，代表当前规则的目标名 (即 libreconic.so)
#  $^:    是另一个自动化变量，代表当前规则的所有依赖项 (即所有.o文件的列表)
$(SHARED_LIB): $(OBJS)
	$(CC) -shared -o $@ $^

# --- 规则：如何生成静态库 ---
# 目标：$(STATIC_LIB) (即 libreconic.a)
# 依赖：$(OBJS) (所有的 .o 目标文件)
# 命令：当所有.o文件都准备好后，执行此命令来打包它们
#  ar: "archiver"工具，用于创建静态库
#  rcs: ar的三个参数
#    r: 如果库中已有同名目标文件，则替换它
#    c: 如果库不存在，则创建它
#    s: 创建一个目标文件索引，这对链接器是必要的
#  $@: 目标名 (libreconic.a)
#  $^: 所有依赖项 (所有.o文件)
$(STATIC_LIB): $(OBJS)
	ar rcs $@ $^

# --- 模式规则：如何从.c文件编译出.o文件 ---
# 这是一个模式规则，它告诉make如何从任何一个.c文件生成对应的.o文件
# 规则：要生成一个名为 "obj/xxx.o" 的文件，需要一个名为 "./xxx.c" 的文件
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	# @符号：在执行命令前，不在终端显示该命令本身
	# mkdir -p: 创建目录，如果父目录不存在也一并创建，且如果目录已存在也不报错
	@mkdir -p $(OBJ_DIR)
	# 编译命令
	# $(CC) $(CFLAGS): 使用带指定标志的gcc
	# -c: 只编译，不链接。这是生成.o文件的关键
	# -o $@: 指定输出文件名，即 "obj/xxx.o"
	# $<: 自动化变量，代表当前规则的第一个依赖项，即 "./xxx.c"
	$(CC) $(CFLAGS) -c -o $@ $<

# --- 清理目标 ---
# "clean" 目标用于删除所有生成的文件，使项目回到干净的状态
clean:
	rm -rf $(OBJ_DIR) $(SHARED_LIB) $(STATIC_LIB)

# --- 伪目标定义 ---
# .PHONY 告诉make，"all" 和 "clean" 这两个目标不是真正的文件名
# 这样做可以防止在当前目录下有名为 "all" 或 "clean" 的文件时，make发生混淆
# 同时也能确保每次执行 "make clean" 时，对应的命令都会被执行
.PHONY: all clean