package com.agrotwin.backend.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "energy_schedule")
public class EnergySchedule {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "olusturulma")
    private String olusturulma;

    @Column(name = "cihaz")
    private String cihaz;

    @Column(name = "planlanan_saat")
    private String planlananSaat;

    @Column(name = "beklenen_fiyat")
    private Double beklenenFiyat;

    @Column(name = "aktif_mi")
    private Integer aktifMi;
}
