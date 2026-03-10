package com.zalocall.zalo_call_recorder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager

class PhoneStateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
            val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            val phoneNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

            when (state) {
                TelephonyManager.EXTRA_STATE_RINGING -> {
                    CallEventHandler.sendCallEvent("incoming", "SIM", phoneNumber)
                }
                TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                    CallEventHandler.sendCallEvent("answered", "SIM", phoneNumber)
                }
                TelephonyManager.EXTRA_STATE_IDLE -> {
                    CallEventHandler.sendCallEvent("ended", "SIM", phoneNumber)
                }
            }
        }
    }
}
