bootpart=1:2
bootdir=/boot
finduuid=part uuid ${boot} ${bootpart} uuid
name_rd=uInitrd
get_rd_mmc=load mmc ${bootpart} ${rdaddr} ${bootdir}/${name_rd}

uenvcmd=run get_rd_${boot}; env set rd_spec ${rdaddr}:${filesize}; setexpr fdtfile sub ti/ti ti; run bootcmd_ti_mmc

optargs=vt.global_cursor_default=0

setbootpart_mmc=true
