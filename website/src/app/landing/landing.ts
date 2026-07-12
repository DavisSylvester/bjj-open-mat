import { Component } from '@angular/core';
import { SiteHeader } from './sections/site-header/site-header';
import { Hero } from './sections/hero/hero';
import { StatBand } from './sections/stat-band/stat-band';
import { HowItWorks } from './sections/how-it-works/how-it-works';
import { MatScenes } from './sections/mat-scenes/mat-scenes';
import { GymOwner } from './sections/gym-owner/gym-owner';
import { JoinCta } from './sections/join-cta/join-cta';
import { SiteFooter } from './sections/site-footer/site-footer';

@Component({
  selector: 'app-landing',
  imports: [SiteHeader, Hero, StatBand, HowItWorks, MatScenes, GymOwner, JoinCta, SiteFooter],
  templateUrl: './landing.html',
  styleUrl: './landing.scss',
})
export class Landing {}
