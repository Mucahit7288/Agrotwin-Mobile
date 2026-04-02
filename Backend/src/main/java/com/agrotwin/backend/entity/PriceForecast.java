package com.agrotwin.backend.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "price_forecasts")
public class PriceForecast {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "timestamp")
    private String timestamp;

    @Column(name = "forecast_hour")
    private String forecastHour;

    @Column(name = "gercek_fiyat")
    private Double gercekFiyat;

    @Column(name = "tahmin_fiyat")
    private Double tahminFiyat;

    @Column(name = "pahali_mi")
    private Integer pahaliMi;

    @Column(name = "ucuz_mu")
    private Integer ucuzMu;
}
