package com.agrotwin.backend.entity;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "sensor_logs")
public class SensorLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @JsonProperty("timestamp")
    @Column(name = "timestamp")
    private String timestamp;

    @JsonProperty("T_ortam")
    @Column(name = "T_ortam")
    private Double tOrtam;

    @JsonProperty("H_ortam")
    @Column(name = "H_ortam")
    private Double hOrtam;

    @JsonProperty("T_su")
    @Column(name = "T_su")
    private Double tSu;

    @JsonProperty("Su_Mesafe_cm")
    @Column(name = "Su_Mesafe_cm")
    private Double suMesafeCm;

    @JsonProperty("Isik_Analog")
    @Column(name = "Isik_Analog")
    private Integer isikAnalog;

    @JsonProperty("elektrik_fiyati")
    @Column(name = "elektrik_fiyati")
    private Double elektrikFiyati;

    @JsonProperty("pompa_karar")
    @Column(name = "pompa_karar")
    private String pompaKarar;

    @JsonProperty("fan_karar")
    @Column(name = "fan_karar")
    private String fanKarar;

    @JsonProperty("isitici_karar")
    @Column(name = "isitici_karar")
    private String isiticiKarar;

    @JsonProperty("tahliye_karar")
    @Column(name = "tahliye_karar")
    private String tahliyeKarar;
}
