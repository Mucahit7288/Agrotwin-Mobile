package com.agrotwin.backend.service;

import com.agrotwin.backend.entity.PriceForecast;
import com.agrotwin.backend.repository.PriceForecastRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class PriceForecastService {

    private final PriceForecastRepository priceForecastRepository;

    public List<PriceForecast> getAll() {
        return priceForecastRepository.findAll();
    }

    public Optional<PriceForecast> getLatest() {
        return priceForecastRepository.findTopByOrderByIdDesc();
    }

    public List<PriceForecast> getPahaliSaatler() {
        return priceForecastRepository.findByPahaliMi(1);
    }

    public List<PriceForecast> getUcuzSaatler() {
        return priceForecastRepository.findByUcuzMu(1);
    }

    public Optional<PriceForecast> getById(Long id) {
        return priceForecastRepository.findById(id);
    }

    public PriceForecast save(PriceForecast priceForecast) {
        return priceForecastRepository.save(priceForecast);
    }

    public void deleteById(Long id) {
        priceForecastRepository.deleteById(id);
    }
}
