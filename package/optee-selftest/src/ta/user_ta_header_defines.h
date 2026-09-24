/* SPDX-License-Identifier: BSD-2-Clause */
/* The name of this file must not be modified. */
#ifndef USER_TA_HEADER_DEFINES_H
#define USER_TA_HEADER_DEFINES_H

#include <selftest_ta.h>

#define TA_UUID			TA_SELFTEST_UUID
#define TA_FLAGS		0
#define TA_STACK_SIZE		(2 * 1024)
#define TA_DATA_SIZE		(32 * 1024)
#define TA_VERSION		"1.0"
#define TA_DESCRIPTION		"Custom OP-TEE self-test TA (inc/sum/sha256/random)"

#endif /* USER_TA_HEADER_DEFINES_H */
