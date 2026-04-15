# ARM7TDMI Technical Documentation

Downloaded on 2026-04-14. This directory contains public technical references
for ARM7TDMI, ARM7TDMI-S, ARMv4T, and the closely related AMBA ARM7TDMI wrapper.

## Downloaded PDFs

| File | Document | Source |
| --- | --- | --- |
| `ARM_DDI_0029G_ARM7TDMI_r3_TRM.pdf` | ARM7TDMI Rev 3 Technical Reference Manual, ARM DDI 0029G | https://datasheet4u.com/pdf-down/A/R/M/ARM7TDMI-ARM.pdf |
| `ARM_DDI_0084F_ARM7TDMI-S_r3_TRM.pdf` | ARM7TDMI-S Rev 3 Technical Reference Manual, ARM DDI 0084F | https://documentation-service.arm.com/static/5e8e1bf9fd977155116a4658 |
| `ARM_DDI_0210C_ARM7TDMI_r4p1_TRM.pdf` | ARM7TDMI Rev r4p1 Technical Reference Manual, ARM DDI 0210C | https://resenv.media.mit.edu/classarchive/MAS961/plug/ARM7TDMI_technical_reference.pdf |
| `ARM_DDI_0234B_ARM7TDMI-S_r4p3_TRM.pdf` | ARM7TDMI-S Rev r4p3 Technical Reference Manual, ARM DDI 0234B | https://documentation-service.arm.com/static/5e8e13a9fd977155116a3368 |
| `ARM_DDI_0045D_AMBA_ARM7TDMI_Interface_Datasheet.pdf` | AMBA ARM7TDMI Interface Data Sheet, ARM DDI 0045D | https://documentation-service.arm.com/static/5e8e15a5fd977155116a3ad6 |
| `ARM_DDI_0100I_ARM_Architecture_Reference_Manual.pdf` | ARM Architecture Reference Manual, ARM DDI 0100I | https://documentation-service.arm.com/static/5f8dacc8f86e16515cdb865a |
| `ARM7TDMI_Data_Sheet_dwedit_mirror.pdf` | ARM7TDMI data sheet mirror | https://www.dwedit.org/files/ARM7TDMI.pdf |
| `ARM7TDMI_Instruction_Set_Quick_Reference_UTexas.pdf` | ARM7TDMI instruction quick reference | https://users.ece.utexas.edu/~mcdermot/arch/articles/ARM/arm7tdmi_quick_reference.pdf |
| `ARM7TDMI_instruction_set_reference_UW_Madison.pdf` | ARM7TDMI instruction set reference mirror | https://raw.githubusercontent.com/velipso/gvasm/main/mirror/arm7tdmi-inst.pdf |

## Local Markdown Notes

| File | Purpose |
| --- | --- |
| `technical_notes.md` | Concise implementation notes distilled from the downloaded references. |
| `additional_reference_notes.md` | Relevant Arm document IDs that were identified but not directly downloaded, with short notes on why they matter. |

## Scope

This folder is intentionally focused on ARM7TDMI-class CPU behavior and hardware
interfaces. Product data sheets for every microcontroller or console SoC that
contains an ARM7TDMI were not exhaustively mirrored, because those mostly cover
vendor peripherals around the core rather than the core itself.
