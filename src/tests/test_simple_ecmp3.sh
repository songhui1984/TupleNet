#!/bin/bash
. env_utils.sh

env_init ${0##*/} # 0##*/ is the filename
sim_create hv1 || exit_test
sim_create hv2 || exit_test
sim_create hv3 || exit_test
sim_create hv4 || exit_test
net_create phy || exit_test
net_join phy hv1 || exit_test
net_join phy hv2 || exit_test
net_join phy hv3 || exit_test
net_join phy hv4 || exit_test

# create logical switch and logical router first
etcd_ls_add LS-A
etcd_ls_add LS-B
etcd_lr_add LR-A

start_tuplenet_daemon hv1 192.168.100.2
GATEWAY=1 ONDEMAND=0 start_tuplenet_daemon hv2 192.168.100.3
GATEWAY=1 ONDEMAND=0 start_tuplenet_daemon hv3 192.168.100.4
GATEWAY=1 ONDEMAND=0 start_tuplenet_daemon hv4 192.168.100.5
install_arp
wait_for_brint # waiting for building br-int bridge

# link LS-A to LR-A
etcd_ls_link_lr LS-A LR-A 10.10.1.1 24 00:00:06:08:06:01
# link LS-B to LR-A
etcd_ls_link_lr LS-B LR-A 10.10.2.1 24 00:00:06:08:06:02
port_add hv1 lsp-portA || exit_test
etcd_lsp_add LS-A lsp-portA 10.10.1.2 00:00:06:08:07:01
port_add hv1 lsp-portB || exit_test
etcd_lsp_add LS-B lsp-portB 10.10.2.2 00:00:06:08:09:01
wait_for_flows_unchange # waiting for install flows

# only get a central_lr, 2 LS, test if script can add ecmp road
! add_ecmp_road hv2 192.168.100.51/24 || exit_test
# adding a new ecmp road
init_ecmp_road hv2 192.168.100.51/24 10.10.1.1/16 192.168.100.1 || exit_test
# test if failed to add ecmp road in same hv
! add_ecmp_road hv2 192.168.100.51/24 || exit_test
wait_for_flows_unchange # waiting for install flows

# send icmp to edge1(hv2) from hv1
ip_src=`ip_to_hex 10 10 1 2`
ip_dst=`ip_to_hex 192 168 100 51`
ttl=09
packet=`build_icmp_request 000006080701 000006080601 $ip_src $ip_dst $ttl af76 8510`
inject_pkt hv1 lsp-portA "$packet" || exit_test
wait_for_packet # wait for packet
ttl=fd
expect_pkt=`build_icmp_response 000006080601 000006080701 $ip_dst $ip_src $ttl bb75 8d10`
real_pkt=`get_tx_pkt hv1 lsp-portA`
verify_pkt $expect_pkt $real_pkt || exit_test


add_ecmp_road hv3 192.168.100.53/24 || exit_test
wait_for_flows_unchange # waiting for install flows

# send icmp to edge2(hv3) from hv1
ip_src=`ip_to_hex 10 10 1 2`
ip_dst=`ip_to_hex 192 168 100 53`
ttl=09
packet=`build_icmp_request 000006080701 000006080601 $ip_src $ip_dst $ttl af76 8510`
inject_pkt hv1 lsp-portA "$packet" || exit_test
wait_for_packet # wait for packet
ttl=fd
expect_pkt=`build_icmp_response 000006080601 000006080701 $ip_dst $ip_src $ttl bb75 8d10`
real_pkt=`get_tx_last_pkt hv1 lsp-portA`
verify_pkt $expect_pkt $real_pkt || exit_test

# send icmp to edge1(hv2) from hv1 again
ip_src=`ip_to_hex 10 10 1 2`
ip_dst=`ip_to_hex 192 168 100 51`
ttl=09
packet=`build_icmp_request 000006080701 000006080601 $ip_src $ip_dst $ttl af76 8510`
inject_pkt hv1 lsp-portA "$packet" || exit_test
wait_for_packet # wait for packet
ttl=fd
expect_pkt=`build_icmp_response 000006080601 000006080701 $ip_dst $ip_src $ttl bb75 8d10`
real_pkt=`get_tx_last_pkt hv1 lsp-portA`
verify_pkt $expect_pkt $real_pkt || exit_test


add_ecmp_road hv4 192.168.100.57/24 || exit_test
wait_for_flows_unchange # waiting for install flows
# send icmp to edge2(hv4) from hv1
ip_src=`ip_to_hex 10 10 1 2`
ip_dst=`ip_to_hex 192 168 100 57`
ttl=09
packet=`build_icmp_request 000006080701 000006080601 $ip_src $ip_dst $ttl af76 8510`
inject_pkt hv1 lsp-portA "$packet" || exit_test
wait_for_packet # wait for packet
ttl=fd
expect_pkt=`build_icmp_response 000006080601 000006080701 $ip_dst $ip_src $ttl bb75 8d10`
real_pkt=`get_tx_last_pkt hv1 lsp-portA`
verify_pkt $expect_pkt $real_pkt || exit_test

# send icmp to edge1(hv2) from hv1 again
ip_src=`ip_to_hex 10 10 1 2`
ip_dst=`ip_to_hex 192 168 100 51`
ttl=09
packet=`build_icmp_request 000006080701 000006080601 $ip_src $ip_dst $ttl af76 8510`
inject_pkt hv1 lsp-portA "$packet" || exit_test
wait_for_packet # wait for packet
ttl=fd
expect_pkt=`build_icmp_response 000006080601 000006080701 $ip_dst $ip_src $ttl bb75 8d10`
real_pkt=`get_tx_last_pkt hv1 lsp-portA`
verify_pkt $expect_pkt $real_pkt || exit_test

# test if we cannot delete edge node in other hv
! remove_ecmp_road hv2 192.168.100.57/24 || exit_test
! remove_ecmp_road hv3 192.168.100.57/24 || exit_test
# now we should delete the third ecmp road
remove_ecmp_road hv4 192.168.100.57/24 || exit_test
wait_for_flows_unchange # waiting for install flows
# send icmp to edge2(hv4) from hv2 by lsp-portB
ip_src=`ip_to_hex 10 10 2 2`
ip_dst=`ip_to_hex 192 168 100 57`
ttl=09
packet=`build_icmp_request 000006080901 000006080602 $ip_src $ip_dst $ttl af76 8510`
inject_pkt hv1 lsp-portB "$packet" || exit_test
wait_for_packet # wait for packet
ttl=fd
expect_pkt="" # should not get any packet
real_pkt=`get_tx_last_pkt hv1 lsp-portB`
verify_pkt $expect_pkt $real_pkt || exit_test

# send icmp to edge1(hv2) from hv1 by lsp-portB
ip_src=`ip_to_hex 10 10 2 2`
ip_dst=`ip_to_hex 192 168 100 51`
ttl=09
packet=`build_icmp_request 000006080901 000006080602 $ip_src $ip_dst $ttl af76 8510`
inject_pkt hv1 lsp-portB "$packet" || exit_test
wait_for_packet # wait for packet
ttl=fd
expect_pkt=`build_icmp_response 000006080602 000006080901 $ip_dst $ip_src $ttl bb75 8d10`
real_pkt=`get_tx_last_pkt hv1 lsp-portB`
verify_pkt $expect_pkt $real_pkt || exit_test

# remove the first road, now we only get the second edge(hv3) road
remove_ecmp_road hv2 192.168.100.51/24 || exit_test
wait_for_flows_unchange # waiting for install flows
# send icmp to edge1(hv2) from hv1 again by lsp-portB
ip_src=`ip_to_hex 10 10 2 2`
ip_dst=`ip_to_hex 192 168 100 53`
ttl=09
packet=`build_icmp_request 000006080901 000006080602 $ip_src $ip_dst $ttl af76 8510`
inject_pkt hv1 lsp-portB "$packet" || exit_test
wait_for_packet # wait for packet
ttl=fd
expect_pkt=`build_icmp_response 000006080602 000006080901 $ip_dst $ip_src $ttl bb75 8d10`
real_pkt=`get_tx_last_pkt hv1 lsp-portB`
verify_pkt $expect_pkt $real_pkt || exit_test


# remove the first road, now we only get the second edge(hv3) road
remove_ecmp_road hv3 192.168.100.53/24 || exit_test
wait_for_flows_unchange # waiting for install flows
# send icmp to edge1(hv2) from hv1 again by lsp-portB
ip_src=`ip_to_hex 10 10 2 2`
ip_dst=`ip_to_hex 192 168 100 53`
ttl=09
packet=`build_icmp_request 000006080901 000006080602 $ip_src $ip_dst $ttl af76 8510`
# we should not receive any feedback, expect_pkt = current packets
expect_pkt="`get_tx_pkt hv1 lsp-portB`"
inject_pkt hv1 lsp-portB "$packet" || exit_test
wait_for_packet # wait for packet
ttl=fd
real_pkt="`get_tx_pkt hv1 lsp-portB`"
verify_pkt "$expect_pkt" "$real_pkt" || exit_test

# only get a central_lr, 2 LS, test if script can add ecmp road
! add_ecmp_road hv4 192.168.100.57/24 || exit_test
# adding a new ecmp road(on hv3)
init_ecmp_road hv4 192.168.100.57/24 10.10.1.1/16 192.168.100.1 || exit_test
wait_for_flows_unchange # waiting for install flows

# send icmp to edge1(hv2) from hv1 again by lsp-portB
ip_src=`ip_to_hex 10 10 2 2`
ip_dst=`ip_to_hex 192 168 100 57`
ttl=09
packet=`build_icmp_request 000006080901 000006080602 $ip_src $ip_dst $ttl af76 8510`
inject_pkt hv1 lsp-portB "$packet" || exit_test
wait_for_packet # wait for packet
ttl=fd
expect_pkt=`build_icmp_response 000006080602 000006080901 $ip_dst $ip_src $ttl bb75 8d10`
real_pkt=`get_tx_last_pkt hv1 lsp-portB`
verify_pkt $expect_pkt $real_pkt || exit_test

pass_test
