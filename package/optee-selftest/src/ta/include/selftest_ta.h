/* SPDX-License-Identifier: BSD-2-Clause */
/* Custom OP-TEE self-test Trusted Application interface. */
#ifndef TA_SELFTEST_H
#define TA_SELFTEST_H

/* UUID (uuidgen) shared by the TA and the host client. */
#define TA_SELFTEST_UUID \
	{ 0x5d6f971b, 0x8fc2, 0x4695, \
		{ 0xb3, 0xb9, 0x1c, 0x58, 0x67, 0x04, 0x63, 0xaf } }

/* Command IDs */
#define TA_SELFTEST_CMD_INC	 0 /* value[0] INOUT: a -> a+1               */
#define TA_SELFTEST_CMD_SUM	 1 /* value[0] IN (a,b); value[1] OUT (a+b)  */
#define TA_SELFTEST_CMD_SHA256	 2 /* memref[0] IN data; memref[1] OUT 32B   */
#define TA_SELFTEST_CMD_RANDOM	 3 /* memref[0] OUT: filled with TRNG bytes  */

#endif /* TA_SELFTEST_H */
